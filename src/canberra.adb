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

package body Canberra is

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

      function Is_Playing
        (Handle     : Context_Handle;
         Identifier : ID;
         Playing    : out Interfaces.C.int) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_playing";

      function Cancel
        (Handle     : Context_Handle;
         Identifier : ID) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_cancel";

      function Play
        (Handle     : Context_Handle;
         Identifier : ID;
         Property_0 : Interfaces.C.char_array;
         Value_0    : Interfaces.C.char_array;
         Property_1 : Interfaces.C.char_array;
         Value_1    : Interfaces.C.char_array;
         Property_2 : Interfaces.C.char_array;
         Value_2    : Interfaces.C.char_array;
         None       : System.Address) return Error_Code
      with Import, Convention => C, External_Name => "ca_context_play";
   end API;

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

   function Is_Playing (Object : Context; Subject : Sound) return Boolean is
      Error   : API.Error_Code;
      Playing : Interfaces.C.int;

      use type Interfaces.C.int;
   begin
      --  Verify that the sound belongs to the context
      if Object.Handle /= Subject.Handle then
         raise Invalid_Sound_Error with "Sound does not belong to context";
      end if;

      Error := API.Is_Playing (Object.Handle, Subject.Identifier, Playing);
      Raise_Error_If_No_Success (Error);

      return Playing /= 0;
   end Is_Playing;

   procedure Cancel (Object : Context; Subject : Sound) is
      Error : API.Error_Code;
   begin
      --  Verify that the sound belongs to the context
      if Object.Handle /= Subject.Handle then
         raise Invalid_Sound_Error with "Sound does not belong to context";
      end if;

      Error := API.Cancel (Object.Handle, Subject.Identifier);
      Raise_Error_If_No_Success (Error);
   end Cancel;

   procedure Play (Object : in out Context; Event_ID : String) is
      Event_Sound : Sound;
   begin
      Object.Play (Event_ID, Event_Sound, Event, Event_ID);
      loop
         exit when not Object.Is_Playing (Event_Sound);
      end loop;
   end Play;

   procedure Play
     (Object      : in out Context;
      Event_ID    : String;
      Event_Sound : out Sound;
      Kind        : Role   := Event;
      Name        : String := "")
   is
      Error : API.Error_Code;

      use type API.Error_Code;
   begin
      Error := API.Play (Object.Handle, Object.Next_ID,
        Interfaces.C.To_C ("event.id"),
        Interfaces.C.To_C (Event_ID),
        Interfaces.C.To_C ("media.role"),
        Interfaces.C.To_C (case Kind is
                             when Event => "event",
                             when Music => "music"),
        Interfaces.C.To_C ("media.name"),
        Interfaces.C.To_C (if Name'Length > 0 then Name else Event_ID),
        System.Null_Address);

      if Error = API.Error_Not_Found then
         raise Event_Not_Found_Error with Event_ID;
      end if;

      Raise_Error_If_No_Success (Error);

      Event_Sound := (Object.Handle, Object.Next_ID);
      Object.Next_ID := Object.Next_ID + 1;
   end Play;

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

end Canberra;
