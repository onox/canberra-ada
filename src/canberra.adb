--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2020 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with Interfaces.C;

with Ada.Unchecked_Deallocation;

package body Canberra is

   procedure Free is new Ada.Unchecked_Deallocation (Sound_Status, Sound_Status_Access);

   package API is
      type Error_Code is
        (Error_Disconnected,
         Error_Forked,
         Error_Disabled,
         Error_Internal,
         Error_IO,
         Error_Access,
         Error_Not_Available,
         Error_Canceled,
         Error_Destroyed,
         Error_Not_Found,
         Error_Too_Big,
         Error_Corrupt,
         Error_System,
         Error_No_Driver,
         Error_Out_Of_Memory,
         Error_State,
         Error_Invalid,
         Error_Not_Supported,
         Success);

      for Error_Code use
        (Error_Disconnected   => -18,
         Error_Forked         => -17,
         Error_Disabled       => -16,
         Error_Internal       => -15,
         Error_IO             => -14,
         Error_Access         => -13,
         Error_Not_Available  => -12,
         Error_Canceled       => -11,
         Error_Destroyed      => -10,
         Error_Not_Found      => -9,
         Error_Too_Big        => -8,
         Error_Corrupt        => -7,
         Error_System         => -6,
         Error_No_Driver      => -5,
         Error_Out_Of_Memory  => -4,
         Error_State          => -3,
         Error_Invalid        => -2,
         Error_Not_Supported  => -1,
         Success              => 0);
      for Error_Code'Size use Interfaces.C.int'Size;

      --------------------------------------------------------------------------

      type Property_List is access System.Address
        with Storage_Size => 0;

      function Create (Handle : in out Property_List) return Error_Code
        with Import, Convention => C, External_Name => "ca_proplist_create";

      function Destroy (Handle : Property_List) return Error_Code
        with Import, Convention => C, External_Name => "ca_proplist_destroy";

      function Set
        (Handle : Property_List;
         Key    : Interfaces.C.char_array;
         Value  : Interfaces.C.char_array) return Error_Code
      with Import, Convention => C, External_Name => "ca_proplist_sets";

      --------------------------------------------------------------------------

      function Create (Handle : in out Context_Handle) return Error_Code
        with Import, Convention => C, External_Name => "ca_context_create";

      function Destroy (Handle : Context_Handle) return Error_Code
        with Import, Convention => C, External_Name => "ca_context_destroy";

      function Change_Property
        (Handle     : Context_Handle;
         Property_0 : Interfaces.C.char_array;
         Value_0    : Interfaces.C.char_array;
         None       : System.Address) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_change_props";

      function Cancel
        (Handle     : Context_Handle;
         Identifier : ID) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_cancel";

      type On_Finish_Callback is access procedure
        (Handle     : Context_Handle;
         Identifier : ID;
         Error      : Error_Code;
         Status     : not null access Sound_Status)
      with Convention => C;

      function Play_Full
        (Handle     : Context_Handle;
         Identifier : ID;
         Properties : Property_List;
         On_Finish  : On_Finish_Callback;
         Status     : not null access Sound_Status) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_play_full";
   end API;

   -----------------------------------------------------------------------------

   protected body Sound_Status is
      entry Wait_For_Completion when Current_Status /= Playing is
      begin
         null;
      end Wait_For_Completion;

      procedure Set_Status (Value : Status_Type) is
      begin
         if not (case Current_Status is
                   when Available => Value = Playing,
                   when Playing   => Value in Finished | Canceled | Failed,
                   when others    => Value in Available | Playing)
         then
            raise Constraint_Error with
              "Cannot change status of sound from " & Current_Status'Image & " to " & Value'Image;
         end if;

         Current_Status := Value;
      end Set_Status;

      function Status return Status_Type is (Current_Status);

      procedure Increment_Ref is
      begin
         References := References + 1;
      end Increment_Ref;

      procedure Decrement_Ref (Is_Zero : out Boolean) is
      begin
         References := References - 1;
         Is_Zero := References = 0;
      end Decrement_Ref;
   end Sound_Status;

   function Status (Object : Sound) return Status_Type is (Object.Status.Status);

   procedure Await_Finish_Playing (Object : Sound) is
   begin
      Object.Status.Wait_For_Completion;
   end Await_Finish_Playing;

   function Belongs_To (Object : Sound; Subject : Context'Class) return Boolean
     is (Object.Handle /= null and Object.Handle = Subject.Handle);

   -----------------------------------------------------------------------------

   procedure Raise_Error_If_No_Success (Error : API.Error_Code) is
      use type API.Error_Code;
   begin
      if Error /= API.Success then
         raise Program_Error with Error'Image;
      end if;
   end Raise_Error_If_No_Success;

   procedure Set_Property (Object : Context; Property, Value : String) is
      Error : API.Error_Code;
   begin
      Error := API.Change_Property (Object.Handle,
        Interfaces.C.To_C (Property),
        Interfaces.C.To_C (Value),
        System.Null_Address);
      Raise_Error_If_No_Success (Error);
   end Set_Property;

   procedure Set_Property (Properties : API.Property_List; Key, Value : String) is
      Error : API.Error_Code;
   begin
      Error := API.Set (Properties, Interfaces.C.To_C (Key), Interfaces.C.To_C (Value));
      Raise_Error_If_No_Success (Error);
   end Set_Property;

   procedure On_Finish
     (Handle     : Context_Handle;
      Identifier : ID;
      Error      : API.Error_Code;
      Status     : not null access Sound_Status)
   with Convention => C;

   procedure On_Finish
     (Handle     : Context_Handle;
      Identifier : ID;
      Error      : API.Error_Code;
      Status     : not null access Sound_Status)
   is
      Is_Zero : Boolean;

      Freeable_Status : Sound_Status_Access := Sound_Status_Access (Status);
   begin
      Status.Set_Status
        (case Error is
           when API.Success        => Finished,
           when API.Error_Canceled => Canceled,
           when others             => Failed);

      Status.Decrement_Ref (Is_Zero);
      if Is_Zero then
         Free (Freeable_Status);
      end if;
   end On_Finish;

   procedure Cancel (Object : Context; Subject : Sound'Class) is
      Error : API.Error_Code;
   begin
      Error := API.Cancel (Object.Handle, Subject.Identifier);
      Raise_Error_If_No_Success (Error);
   end Cancel;

   procedure Play (Object : in out Context; Event_ID : String) is
      Event_Sound : Sound;
   begin
      Object.Play (Event_ID, Event_Sound, Event, Event_ID);
      Event_Sound.Status.Wait_For_Completion;
   end Play;

   procedure Play_Internal
     (Object         : in out Context;
      Property_Name  : String;
      Property_Value : String;
      Kind           : Role;
      Name           : String;
      The_Sound      : out Sound'Class)
   is
      Error : API.Error_Code;
      Properties : API.Property_List;

      use type API.Error_Code;

      Is_Zero : Boolean;
   begin
      Raise_Error_If_No_Success (API.Create (Properties));

      Set_Property (Properties, Property_Name, Property_Value);
      Set_Property (Properties, "media.role", (case Kind is
                             when Event => "event",
                             when Music => "music"));
      Set_Property (Properties, "media.name", (if Name'Length > 0 then Name else Property_Value));

      The_Sound.Status.Increment_Ref;
      The_Sound.Status.Set_Status (Playing);

      Error := API.Play_Full
        (Object.Handle,
         Object.Next_ID,
         Properties,
         On_Finish'Access,
         The_Sound.Status);

      if Error /= API.Success then
         The_Sound.Status.Set_Status (Failed);
         The_Sound.Status.Decrement_Ref (Is_Zero);
      end if;

      Raise_Error_If_No_Success (API.Destroy (Properties));

      if Error = API.Error_Not_Found then
         raise Not_Found_Error with Property_Value;
      end if;

      Raise_Error_If_No_Success (Error);

      The_Sound.Handle     := Object.Handle;
      The_Sound.Identifier := Object.Next_ID;
      Object.Next_ID := Object.Next_ID + 1;
   end Play_Internal;

   procedure Play
     (Object      : in out Context;
      Event_ID    : String;
      Event_Sound : out Sound'Class;
      Kind        : Role   := Event;
      Name        : String := "")
   is
   begin
      Play_Internal
        (Object         => Object,
         Property_Name  => "event.id",
         Property_Value => Event_ID,
         Kind           => Kind,
         Name           => Name,
         The_Sound      => Event_Sound);
   end Play;

   procedure Play_File
     (Object      : in out Context;
      File_Name   : String;
      File_Sound  : out Sound'Class;
      Kind        : Role   := Event;
      Name        : String := "")
   is
   begin
      Play_Internal
        (Object         => Object,
         Property_Name  => "media.filename",
         Property_Value => File_Name,
         Kind           => Kind,
         Name           => Name,
         The_Sound      => File_Sound);
   end Play_File;

   function Create (Name, ID, Icon : String := "") return Context is
      Error : API.Error_Code;
   begin
      return Object : Context do
         Error := API.Create (Object.Handle);
         Raise_Error_If_No_Success (Error);

         if Name'Length > 0 then
            Object.Set_Property ("application.name", Name);
         end if;

         if ID'Length > 0 then
            Object.Set_Property ("application.id", ID);
         end if;

         if Icon'Length > 0 then
            Object.Set_Property ("application.icon_name", Icon);
         end if;
      end return;
   end Create;

   overriding procedure Finalize (Object : in out Context) is
      Error : API.Error_Code;
   begin
      if Object.Handle /= null then
         Error := API.Destroy (Object.Handle);
         Raise_Error_If_No_Success (Error);
         Object.Handle := null;
      end if;
   end Finalize;

   overriding procedure Initialize (Object : in out Sound) is
   begin
      Object.Status := new Sound_Status;
      Object.Status.Increment_Ref;
   end Initialize;

   overriding procedure Finalize (Object : in out Sound) is
      Is_Zero : Boolean;
   begin
      Object.Status.Decrement_Ref (Is_Zero);
      if Is_Zero then
         Free (Object.Status);
      end if;
   end Finalize;

end Canberra;
