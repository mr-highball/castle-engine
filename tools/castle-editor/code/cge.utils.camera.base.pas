unit cge.utils.camera.base;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  CastleKeysMouse,
  CastleVectors,
  CastleLog,
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
      Const AInput:TInputMotion;Const ACamera:TCamera);
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
  const ACamera: TCamera; const AType: TCameraEventType);
begin
  //todo - handle zooming
end;

procedure TCameraControllerImpl.DoPan(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
begin
  //todo - handle panning
end;

procedure TCameraControllerImpl.DoRotate(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
begin
  //todo - handle rotation
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
    DoPan(AInput,ACamera,AType,AFactor);
  except on E:Exception do
    if Log then
      WriteLnLog(Self.Classname + '::DoPan::' + E.Message);
  end;
end;

procedure TCameraControllerImpl.Rotate(const AInput: TInputMotion;
  const ACamera: TCamera; const AFactor: Integer);
begin
  try
    DoRotate(AInput,ACamera,AType,AFactor);
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

