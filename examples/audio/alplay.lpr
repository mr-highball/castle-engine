{
  Copyright 2003-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Simply load and play sound file using OpenAL. }
program alplay;

{$I castleconf.inc}

uses SysUtils, CastleUtils,
  CastleLog, CastleSoundEngine, CastleParameters, CastleTimeUtils, CastleVectors,
  CastleApplicationProperties;

var
  Buffer: TSoundBuffer;
  URL: string;
begin
  ApplicationProperties.OnWarning.Add(
    {$ifdef CASTLE_OBJFPC}@{$endif} ApplicationProperties.WriteWarningOnConsole);

  InitializeLog; // to see various info about OpenAL and sound loading

  { parse params }
  SoundEngine.ParseParameters;
  Parameters.CheckHigh(1);
  URL := Parameters[1];

  { Change the default MinAllocatedSources (it may be larger for the default
    engine usage, as we expect that some sound mixing will be needed;
    for this demo, 1 is enough). }
  SoundEngine.MinAllocatedSources := 1;

  { Load and play sound, without any spatialization.
    OpenAL will be automatically initialized when needed below.
    Although you could also initialize it explicitly by SoundEngine.ALContextOpen,
    check SoundEngine.SoundInitializationReport, SoundEngine.ALActive etc. }
  Buffer := SoundEngine.LoadBuffer(URL);
  Writeln('Sound loaded, duration in seconds: ', Buffer.Duration:1:2);
  SoundEngine.PlaySound(Buffer);

  { Wait enough time to finish playing. (because PlaySound above doesn't block).
    In this simple program, we just sleep enough time
    to finish playing sound, with some margin. Alternative, more precise way
    to do this would be query is sound playing (call SoundEngine.Refresh
    from time to time, and watch out for TSound.OnRelease event;
    PlaySound returns TSound instance for such purposes). }
  Sleep(Round(Buffer.Duration * 1000) + 500);
end.
