unit cge.utils.camera;

{$mode delphi}{$H+}
{$ModeSwitch nestedprocvars} //todo - can remove if we don't use but may...

interface

uses
  Classes,
  SysUtils,
  CastleVectors,
  CastleKeysMouse,
  CastleCameras;

type

  (*
    enum defining possible events handled by the camera controller
  *)
  TCameraEventType = (
    ceNone,
    ceZoom,
    cePan,
    ceRotate
  );

  { ICameraController }
  (*
    main interface for interacting with a castle design scene
  *)
  ICameraController = interface
    ['{950D8E5B-C358-4978-BE1B-CFC7725606BE}']
    //property methods
    function GetOrigin: TVector3;
    procedure SetOrigin(AValue: TVector3);

    //properties
    (*
      origin is the equivalent to the blender 3d cursor, or in more agnostic
      terms, the 3d location that camera events are calculated with
      when a 2d motion event (mouse drag etc...) is performed
    *)
    property Origin : TVector3 read GetOrigin write SetOrigin;

    //methods
    procedure HandleEvent(Const AEvent:TCameraEventType;
      Const AInput:TInputMotion;Const ACamera:TCamera);
  end;

  (*
    helper method for returning the proper event type based on the type
    of motion being performed by the end user
  *)
  function CameraEventFromInput(Const AInput:TInputMotion):TCameraEventType;

implementation

function CameraEventFromInput(const AInput: TInputMotion): TCameraEventType;
begin
  Result:=ceNone;
  try
    //todo - need check old pos and new pos with keyboard state to determine
    //       what type of event is being performed (if any)
  except on E:Exception do
    //todo - write to the castle log that an error has occurred
  end;
end;

end.

