unit cge.utils.camera.base;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  CastleKeysMouse,
  CastleVectors,
  CastleLog, CastleVectorsInternalSingle,
  CastleCameras,
  cge.utils.camera;

type

  { TCamerControllerImpl }
  (*
    base camera controller implementation offering overridable methods
    for children classes
  *)

  { TCameraControllerImpl }

  TCameraControllerImpl = class(TInterfacedobject,ICameraController)
  strict private
    FOrigin: TVector3;
    function GetOrigin: TVector3;
    procedure SetOrigin(Const AValue: TVector3);
  strict protected
    procedure DoZoom(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AType:TCameraEventType=ceZoomIn;Const AFactor:Integer=1);virtual;
    procedure DoPan(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);virtual;
    procedure DoRotate(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);virtual;
  public
    //properties
    property Origin : TVector3 read GetOrigin write SetOrigin;

    //methods
    procedure HandleEvent(Const AType:TCameraEventType;
      Const AInput:TInputMotion;Const ACamera:TCamera;Const AFactor:Integer=1);
    procedure Zoom(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AType:TCameraEventType=ceZoomIn;Const AFactor:Integer=1);
    procedure Pan(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);
    procedure Rotate(Const AInput:TInputMotion;Const ACamera:TCamera;
      Const AFactor:Integer=1);
    constructor Create;virtual;
    destructor Destroy; override;
  end;

implementation
uses
  Math,
  CastleQuaternions;

{ TCameraControllerImpl }

function TCameraControllerImpl.GetOrigin: TVector3;
begin
  Result:=FOrigin;
end;

procedure TCameraControllerImpl.SetOrigin(Const AValue: TVector3);
begin
  FOrigin:=AValue;
end;

procedure TCameraControllerImpl.DoZoom(Const AInput:TInputMotion;
  const ACamera: TCamera; const AType: TCameraEventType;Const AFactor:Integer=1);
begin
  //todo - handle zooming
end;

procedure TCameraControllerImpl.DoPan(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
var
  LPos: TVector3;
  LDelta: TGenericScalar;
begin
  //todo - handle panning
  LPos:=ACamera.Position;

  //find new x position
  LDelta:=AInput.Position.X - AInput.OldPosition.X;
  LPos.X:=LPos.X + (LDelta * AFactor);

  //find new y position
  LDelta:=AInput.Position.Y - AInput.OldPosition.Y;
  LPos.Y:=LPos.Y + (LDelta * AFactor);

  //update camera position
  ACamera.Position:=LPos;
end;

procedure TCameraControllerImpl.DoRotate(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
var
  LQuat: TQuaternion;
  LDeltaY, LDeltaX: TGenericScalar;
  LRad: float;
  LOldPos, LNewPos: TVector3;
begin
  //todo - handle rotation

  //find deltas to calculate angle radians
  //https://stackoverflow.com/questions/15994194/how-to-convert-x-y-coordinates-to-an-angle
  LDeltaY:=AInput.Position.Y - AInput.OldPosition.Y;
  LDeltaX:=AInput.Position.X - AInput.OldPosition.X;
  LRad:=arctan2(LDeltaY,LDeltaX);

  //get quaternion
  LQuat:=QuatFromAxisAngle(
    FOrigin,
    LRad,
    True
  );
  LOldPos:=ACamera.Position;
  //copied from CastleCameras TExamineCamera.SetViewSetView
  //ACamera.Position:=LQuat.Rotate(ACamera.Position); //not really doing anything, need to read up on this
  LNewPos:=LOldPos;
  LNewPos.X:=ACamera.Position.X + 1;
  ACamera.Position:=LNewPos;
end;

procedure TCameraControllerImpl.HandleEvent(const AType: TCameraEventType;
  const AInput: TInputMotion; const ACamera: TCamera;Const AFactor:Integer);
begin
  //redirect handling to proper specialized methods
  case AType of
    ceNone : Exit;
    ceZoomIn : Zoom(AInput,ACamera,ceZoomIn);
    ceZoomOut : Zoom(AInput,ACamera,ceZoomOut);
    ceRotate : Rotate(AInput,ACamera);
    cePan : Pan(AInput,ACamera);
  end;
end;

procedure TCameraControllerImpl.Zoom(Const AInput:TInputMotion;
  const ACamera: TCamera; const AType: TCameraEventType;
  const AFactor: Integer);
begin
  try
    DoZoom(AInput,ACamera,AType,AFactor);
  except on E:Exception do
    if Log then
      WriteLnLog(Self.Classname + '::DoZoom::' + E.Message);
  end;
end;

procedure TCameraControllerImpl.Pan(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
begin
  try
    DoPan(AInput,ACamera,AFactor);
  except on E:Exception do
    if Log then
      WriteLnLog(Self.Classname + '::DoPan::' + E.Message);
  end;
end;

procedure TCameraControllerImpl.Rotate(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
begin
  try
    DoRotate(AInput,ACamera,AFactor);
  except on E:Exception do
    if Log then
      WriteLnLog(Self.Classname + '::DoRotate::' + E.Message);
  end;
end;

constructor TCameraControllerImpl.Create;
begin
  //initialize the origin to center
  FOrigin:=TVector3.Zero;
end;

destructor TCameraControllerImpl.Destroy;
begin
  inherited Destroy;
end;

end.

