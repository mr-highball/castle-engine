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
    ceZoomIn,
    ceZoomOut,
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
    procedure SetOrigin(Const AValue: TVector3);

    //properties
    (*
      origin is the equivalent to the blender 3d cursor, or in more agnostic
      terms, the 3d location that camera events are calculated with
      when a 2d motion event (mouse drag etc...) is performed
    *)
    property Origin : TVector3 read GetOrigin write SetOrigin;

    //methods
    (*
      handles all types of camera events correctly repositioning
      the provided camera
    *)
    procedure HandleEvent(Const AType:TCameraEventType;
      Const AInput:TInputMotion;Const ACamera:TCamera);

    (*
      specialized zoom method allowing an amount, will assume zoom in
      if invalid event type is used
    *)
    procedure Zoom(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AType:TCameraEventType=ceZoomIn;Const AFactor:Integer=1);

    (*
      specialized pan method allowing pan factor
    *)
    procedure Pan(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);

    (*
      specialized rotate method allowing rotate factor
    *)
    procedure Rotate(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);
  end;

  (*
    helper method for returning the proper event type based on the type
    of motion being performed by the end user
  *)
  function CameraEventFromInput(Const AKeys:TKeysPressed;
    Const AInput:TInputMotion):TCameraEventType;

implementation
uses
  CastleLog;

function CameraEventFromInput(Const AKeys:TKeysPressed;
  const AInput: TInputMotion): TCameraEventType;
begin
  Result:=ceNone;
  try
    //no buttons return none
    if AInput.Pressed=[] then
      Exit;

    //pan state is middle mouse and shift to mimic blender
    if (AInput.Pressed=[mbMiddle]) and AKeys.Keys[keyShift] then
      Exit(cePan)
    //rotate occurs when middle mouse is used but no shift key is pressed
    else if (AInput=[mbMiddle]) and not AKeys[keyShift] then
      Exit(ceRotate)
    //while most people will use the scroll wheel to zoom in and out,
    //here are some alternate methods by using the shift and either
    //left or right mouse button
    else if (AInput=[mbLeft] or AInput=[mbRight]) and AKeys[keyShift] then
    begin
      if AInput.OldPosition.Y < AInput.Position.Y then
        Exit(ceZoomIn)
      else
        Exit(ceZoomOut);
    end;
  except on E:Exception do
    //determine if castle log is initialized or not before writing
    if Log then
      WritelnLog(E.Message);
  end;
end;

end.

