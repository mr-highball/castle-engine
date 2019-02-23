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

  //todo - change factors to singles not integers

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
      Const AInput:TInputMotion;Const ACamera:TCamera;Const AFactor:Integer=1);

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
  function CameraEventFromInput(Const AEvent:TInputPressRelease;
    Const AInput:TInputMotion):TCameraEventType;

implementation
uses
  CastleLog;

function CameraEventFromInput(Const AEvent:TInputPressRelease;
  const AInput: TInputMotion): TCameraEventType;
begin
  Result:=ceNone;
  try
    //use the input motion pressed set to see if no operation, exit if so
    if AInput.Pressed=[] then
      Exit;

    //todo - we've switched form passing just the mouse buttons set
    //to handle events easier, but the InputPressRelease event is either
    //a mouse event, or button event, so the getting the keys and the buttons
    //seems to be a problem, may need to switch this method to take TMouseButtons
    //and a TKeys set or something...

    //pan state is middle mouse and shift to mimic blender
    if (AEvent.IsMouseButton(mbMiddle)) and (mkShift in AEvent.ModifiersDown) then
      Exit(cePan)
    //rotate occurs when middle mouse is used but no shift key is pressed
    else if (AEvent.IsMouseButton(mbMiddle)) and not(mkShift in AEvent.ModifiersDown) then
      Exit(ceRotate)
    //while most people will use the scroll wheel to zoom in and out,
    //here are some alternate methods by using the shift and either
    //left or right mouse button
    else if ((AEvent.IsMouseButton(mbLeft)) or (AEvent.IsMouseButton(mbRight))) and (mkShift in AEvent.ModifiersDown) then
    begin
      if AInput.OldPosition.Y < AInput.Position.Y then
        Exit(ceZoomIn)
      else
        Exit(ceZoomOut);
    end
    //return standard zoom operations from mousewheel
    else if AEvent.MouseWheel=mwDown then
      Exit(ceZoomOut)
    else if AEvent.MouseWheel=mwUp then
      Exit(ceZoomIn);
  except on E:Exception do
    //determine if castle log is initialized or not before writing
    if Log then
      WritelnLog(E.Message);
  end;
end;

end.

