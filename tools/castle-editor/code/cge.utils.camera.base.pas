unit cge.utils.camera.base;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  CastleVectors,
  cge.utils.camera;

type

  { TCamerControllerImpl }
  (*
    base camera controller implementation offering overridable methods
    for children classes
  *)
  TCamerControllerImpl = class(TInterfacedbject,ICameraController)
  strict private
  strict protected
  public
  end;

implementation

end.

