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

private with System;

private with Ada.Finalization;

package Canberra with SPARK_Mode => On is
   pragma Preelaborate;

   type Context is tagged limited private;

   function Create (Name, ID, Icon : String := "") return Context;

   procedure Set_Property (Object : Context; Property, Value : String);

   -----------------------------------------------------------------------------

   type Sound is tagged limited private;

   function Belongs_To (Object : Sound; Subject : Context'Class) return Boolean;
   --  Return True if the sound was created by the given context, False otherwise
   --
   --  If True, then procedure Cancel can be used to cancel playing the sound.

   type Status_Type is (Available, Playing, Finished, Canceled, Failed);

   function Status (Object : Sound) return Status_Type;
   --  Return the current status of the sound

   procedure Await_Finish_Playing (Object : Sound);
   --  Wait until the status is no longer Playing

   -----------------------------------------------------------------------------

   type Role is (Event, Music);

   procedure Play (Object : in out Context; Event_ID : String);
   --  Play an event sound and wait for it to finish playing
   --
   --  Raises Not_Found_Error if the event was not found.

   procedure Play
     (Object      : in out Context;
      Event_ID    : String;
      Event_Sound : out Sound'Class;
      Kind        : Role   := Event;
      Name        : String := "")
   with Pre'Class  => Event_Sound.Status /= Playing,
        Post'Class => Event_Sound.Status in Playing | Finished | Failed
                        and then Event_Sound.Belongs_To (Object);
   --  Play an event or music sound and return the sound so that it can
   --  be optionally cancelled
   --
   --  This subprogram returns immediately and does not wait for the sound
   --  to finish playing.
   --
   --  Raises Not_Found_Error if the event was not found.

   procedure Play_File
     (Object      : in out Context;
      File_Name   : String;
      File_Sound  : out Sound'Class;
      Kind        : Role   := Event;
      Name        : String := "")
   with Pre'Class  => File_Sound.Status /= Playing,
        Post'Class => File_Sound.Status in Playing | Finished | Failed
                        and then File_Sound.Belongs_To (Object);
   --  Play an audio file and return the sound so that it can
   --  be optionally cancelled
   --
   --  This subprogram returns immediately and does not wait for the sound
   --  to finish playing.
   --
   --  Raises Not_Found_Error if the file was not found.

   procedure Cancel (Object : Context; Subject : Sound'Class)
     with Pre'Class => Subject.Status /= Available and then Subject.Belongs_To (Object);
   --  Stop playing the given sound

   Not_Found_Error : exception;

private

   pragma SPARK_Mode (Off);

   type Context_Handle is access System.Address
     with Storage_Size => 0;

   type ID is mod 2 ** 32
     with Size => 32;

   type Context is limited new Ada.Finalization.Limited_Controlled with record
      Handle  : Context_Handle := null;
      Next_ID : ID             := 0;
   end record;

   overriding procedure Finalize (Object : in out Context);

   -----------------------------------------------------------------------------

   protected type Sound_Status is
      entry Wait_For_Completion;

      procedure Set_Status (Value : Status_Type);

      function Status return Status_Type;

      procedure Increment_Ref;
      procedure Decrement_Ref (Is_Zero : out Boolean);
   private
      Current_Status : Status_Type := Available;
      References     : Natural     := 0;
   end Sound_Status;

   type Sound_Status_Access is access all Sound_Status;

   type Sound is limited new Ada.Finalization.Limited_Controlled with record
      Handle     : Context_Handle := null;
      --  Handle might point to invalid memory if its context has been
      --  finalized, but it is only used to verify that the sound belongs
      --  to the calling context

      Identifier : ID := ID'Last;

      Status : Sound_Status_Access := null;
   end record
     with Type_Invariant => Sound.Status /= null;

   overriding procedure Initialize (Object : in out Sound);

   overriding procedure Finalize (Object : in out Sound);

end Canberra;
