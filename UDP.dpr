program UDP;

uses
  Vcl.Forms,
  uPrincipal in 'uPrincipal.pas' {Form1},
  udsp_network in 'udsp_network.pas',
  uFra_Global in 'uFra_Global.pas',
  ux_dao_lite in 'ux_dao_lite.pas',
  DM in 'DM.pas' {DataModule1: TDataModule},
  ux_log in 'ux_log.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.Run;
end.
