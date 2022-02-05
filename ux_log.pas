unit ux_log;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs;

{-----------------------------------------------------------------------------}
  Function ux_log_pasta() : String;
  Procedure ux_log_Text(Dados:String);

{-----------------------------------------------------------------------------}

implementation

Function ux_log_pasta() : String;
var
  Pasta_App : String;
  Pasta_Ano : String;
  Pasta_Mes : String;
  Pasta_Log : String;
begin
  Try
    Pasta_App := (ExtractFilePath(Application.ExeName)+ 'Log');
    Pasta_Ano := FormatDateTime('yyyy',date);
    Pasta_Mes := UpperCase(FormatDateTime('mm',date)) + ' - ' + UpperCase(FormatDateTime('mmmm',date));
    Pasta_Log :=  Pasta_App + '\' + Pasta_Ano + '\' + Pasta_Mes;
    if not DirectoryExists(Pasta_App) then
      CreateDir(Pasta_App);
    if not DirectoryExists(Pasta_App + '\' + Pasta_Ano) then
      CreateDir(Pasta_App + '\' + Pasta_Ano);
    if not DirectoryExists(Pasta_Log) then
      CreateDir(Pasta_Log);
    Result := Pasta_Log + '\';
  Except
   Result := (ExtractFilePath(Application.ExeName));
  End;
end;

Procedure ux_log_Text(Dados:String);
var
  log: textfile;
  arquivo:string;
  DadosTxt:string;
  Pasta_Log : String;
  Pasta_Ano : String;
  Pasta_Mes : String;
begin
  try
    Pasta_Ano := FormatDateTime('yyyy',date);
    Pasta_Mes := UpperCase(FormatDateTime('mmmm',date));
    DadosTxt := '';
    if trim(Dados) <> '' then
      Begin
        DadosTxt := DateToStr(date) + ' ' + TimeToStr(time);
        DadosTxt := DadosTxt + ' :: ' + Dados;
      End
  Else
    DadosTxt := Dados;
  arquivo := ux_log_pasta + 'core.dlog';
  AssignFile(log, arquivo);
  if not FileExists(arquivo) then Rewrite(log,arquivo);
  Append(log);
  WriteLn(log, DadosTxt);
  finally
  CloseFile(log);
  end;
end;

end.
