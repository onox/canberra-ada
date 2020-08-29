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
   pragma Pure;

   type Context is tagged limited private;

   function Create (Name, ID, Icon : String := "") return Context;

   procedure Set_Property (Object : Context; Property, Value : String);

   type Sound is private;

   type Role is (Event, Music);

   procedure Play (Object : in out Context; Event_ID : String);
   --  Play an event sound and wait for it to finish playing
   --
   --  Raises Event_Not_Found_Error if the event was not found.

   procedure Play
     (Object      : in out Context;
      Event_ID    : String;
      Event_Sound : out Sound;
      Kind        : Role   := Event;
      Name        : String := "");
   --  Play an event or music sound and return the sound so that it can
   --  be optionally cancelled
   --
   --  This subprogram returns immediately and does not wait for the sound
   --  to finish playing.
   --
   --  Raises Not_Found_Error if the event was not found.

   procedure Play_File
     (Object      : in out Context;
      Filename    : String;
      File_Sound  : out Sound;
      Kind        : Role   := Event;
      Name        : String := "");
   --  Play an audio file and return the sound so that it can
   --  be optionally cancelled
   --
   --  This subprogram returns immediately and does not wait for the sound
   --  to finish playing.
   --
   --  Raises Not_Found_Error if the file was not found.

   function Is_Playing (Object : Context; Subject : Sound) return Boolean;
   --  Return True if the sound is still playing, False otherwise
   --
   --  Raises Invalid_Sound_Error if the sound was played by a different
   --  context.

   procedure Cancel (Object : Context; Subject : Sound);
   --  Stop playing the given sound
   --
   --  Raises Invalid_Sound_Error if the sound was played by a different
   --  context.

   Invalid_Sound_Error : exception;

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

   type Sound is record
      Handle     : Context_Handle := null;
      --  Handle might point to invalid memory if its context has been
      --  finalized, but it is only used to verify that the sound belongs
      --  to the calling context
      Identifier : ID := 0;
   end record;

end Canberra;
