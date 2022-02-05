unit udsp_network;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Easy_UDP1, StdCtrls,WinInet, ComCtrls,ShellApi;
{**************************}
{**************************}
var
  UDPSocket : EUDPSocket;
  {Variáveis do Módulo Remoto}
  vSA_COMREMOTO_Porta  : integer = 10000;
  vSA_COMREMOTO_LogDet : Boolean = false;
  vSa_ftp_host : string;
  vSa_ftp_us   : string;
  vSa_ftp_pw   : string;
  vSa_ftp_dir  : string;
  vSa_ftp_arq  : string;
  vSa_ftp_dest : string;
  vSa_ftp_prog : TProgressBar;
{******************************************************************}
procedure UDPOnerror(Msg : string);
procedure UDPOnReceive(Host: string; Port: word; const Buffer: EUDPBuffer; Size: integer);
Procedure SA_ComRemoto_Log(Dados:String);
Function SA_COMREMOTO_Inicializar() : Boolean;
Function SA_COMREMOTO_Finalizar() : Boolean;
Function SA_COMREMOTO_EnviaDados(Host:String;Porta:integer;Dados:String) : Boolean;
Function SA_COMREMOTO_Processa(Dados,Host:String):Boolean;
{*****************************************************************}


implementation

uses
  uFra_Global, uPrincipal, ux_dao_lite;
//uses uFrmPrincipal, UFrmGeraAceFunc, udsp_global;
{**************************}
Function DspPastaLogRemoto() : String;
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
{**************************}
Procedure SA_COMREMOTO_Log(Dados:String);
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
  arquivo := DspPastaLogRemoto + 'DspSaComRemota.dlog';
  AssignFile(log, arquivo);
  if not FileExists(arquivo) then Rewrite(log,arquivo);
  Append(log);
  WriteLn(log, DadosTxt);
  finally
  CloseFile(log);
  end;
end;

{*****************************************************************}
procedure UDPOnerror(Msg : string);
begin
   SA_ComRemoto_Log('Alerta ao Receber Dados .:. ' + Msg);
end;
{*****************************************************************}


procedure UDPOnReceive(Host: string; Port: word; const Buffer: EUDPBuffer; Size: integer);
var S : string[255];
begin
  Try
    {Recebe e Converte Dados}
    move(Buffer, S, Size);
    {Inicia Processamento}
    SA_COMREMOTO_Processa(s,host);
  Except
    On e : Exception do
      Begin
        SA_ComRemoto_Log('Erro ao Processa Dados Recebidos .:. ' + e.Message);
      End;
  End;

  {Log Detalhado}
  if vSA_COMREMOTO_LogDet then
    SA_ComRemoto_Log('Frame Recebido: ' + #10 +
                     'Origem: ' + Host + ':' + inttostr(Port) + #10 +
                     'Dados : ' + S);
end;
{********************************************************************}
Function SA_COMREMOTO_Inicializar() : Boolean;
begin
  Try
    UDPSocket := EUDPSocket.Create; //create socket
    UDPSocket.OnError := UDPOnError;
    UDPSocket.OnReceive := UDPOnReceive;
    UDPSocket.Start(vSA_COMREMOTO_Porta);
    SA_ComRemoto_Log(' ');
    SA_ComRemoto_Log('Módulo de Comunicação UDP Inicializada .:. Porta: ' + inttostr(vSA_COMREMOTO_Porta));
    Result := True;
  Except
    On e : Exception do
      Begin
        SA_ComRemoto_Log('Erro ao Inicializar Módulo de Comunicação UDP .:. Porta: ' + inttostr(vSA_COMREMOTO_Porta));
        Result := False;
        UDPSocket.Destroy;
        UDPSocket := nil;
      End;
  End;
End;
{*******************************************************************}
 Function SA_COMREMOTO_Finalizar() : Boolean;
begin
  Try
    if assigned(UDPSocket) then
      begin
        UDPSocket.Destroy;
        UDPSocket := nil;
      end;
      Result := True;
      SA_ComRemoto_Log('Módulo de Comunicação UDP Finalizado .:. Porta: ' + inttostr(vSA_COMREMOTO_Porta));
  Except
    On e : Exception do
      Begin
        SA_ComRemoto_Log('Erro ao Finalizar Módulo de Comunicação UDP .:. Porta: ' + inttostr(vSA_COMREMOTO_Porta));
        Result := False;
      End;
  End;
End;
{******************************************************************}
Function SA_COMREMOTO_EnviaDados(Host:String;Porta:integer;Dados:String) : Boolean;
var S : string[255];
begin
  Try
    S := Dados;
    if UDPSocket.SendData(Host,Porta,S, length(S)+1) > 0 then
      Begin

      End
    else
      Begin
        SA_ComRemoto_Log('Alerta ao Trasmitir dados:' + #10 +
                         ' -	 Destino: ' + Host + #10 +
                         ' - Porta  : ' + inttostr(Porta) + #10 +
                         ' - Frame  : ' + Dados);
        End;
  Except
    On e : Exception do
      Begin
        SA_ComRemoto_Log('Alerta ao Transmitir Dados .:. ' + E.Message);
        SA_ComRemoto_Log(' - Destino: ' + Host + #10 +
                         ' - Porta  : ' + inttostr(Porta) + #10 +
                         ' - Frame  : ' + Dados);
      End;
  end;
end;
{****************************************************************}
Function SA_COMREMOTO_Processa(Dados,Host:String):Boolean;
var
teste:string;
Begin
  Try
    SA_ComRemoto_Log('[' + Host + '] :: ' + Dados);
    if Copy(Dados,1,2) = 'F@' then
      Begin
        // Colocar os valores nas variaveis.
        vCom_Confirma := True;
        vCom_Ret:= copy(Dados,4,10);
        vCom_RetTipo:= strtoint(copy(Dados,3,1));
        Result := True;

       teste:=ux_lite_sqlInsert('INSERT INTO TB_NOME (nome,idade)values(:p1,:p2)',vCom_Ret,20);
       if teste = 'ok' then
       begin
          SA_COMREMOTO_EnviaDados('192.168.0.3',20000,'Dados Cadastrados');
       end;
       Exit;
      End
    Else
      Begin
        SA_ComRemoto_Log('Pacote descartado: [' + Host + ']' + ' :: ' + Dados);
        vCom_Confirma := False;
        vCom_Ret := '';
        vCom_RetTipo := 0;
        Result := False;
        Exit;
      End;
  Except
    On e : Exception do
      Begin
        SA_ComRemoto_Log('Erro ao processa: [' + Host + ']' + ' :: ' + Dados +
                         ' .:. ' + e.Message);
        Result := False;
      End;
  End;
  {if Dados <> '[ROK]' then
  SA_COMREMOTO_EnviaDados(Host,vSA_COMREMOTO_Porta,'[ROK]');}
End;
{**************************}
function sa_ftp_download(strHost, strUser, strPwd: string;
  Port: Integer; ftpDir, ftpFile, TargetFile: string; ProgressBar: TProgressBar): Boolean;
  function FmtFileSize(Size: Integer): string;
  begin
    if Size >= $F4240 then
      Result := Format('%.2f', [Size / $F4240]) + ' Mb'
    else
    if Size < 1000 then
      Result := IntToStr(Size) + ' bytes'
    else
      Result := Format('%.2f', [Size / 1000]) + ' Kb';
  end;
const
  READ_BUFFERSIZE = 4096;  // or 256, 512, ...
var
  hNet, hFTP, hFile: HINTERNET;
  buffer: array[0..READ_BUFFERSIZE - 1] of Char;
  bufsize, dwBytesRead, fileSize: DWORD;
  sRec: TWin32FindData;
  strStatus: string;
  LocalFile: file;
  bSuccess: Boolean;
begin
  Result := False;
  { Open an internet session }
  hNet := InternetOpen('Program_Name', // Agent
                        INTERNET_OPEN_TYPE_PRECONFIG, // AccessType
                        nil,  // ProxyName
                        nil, // ProxyBypass
                        0); // or INTERNET_FLAG_ASYNC / INTERNET_FLAG_OFFLINE
  {
    Agent contains the name of the application or
    entity calling the Internet functions
  }

  { See if connection handle is valid }
  if hNet = nil then
  begin
    //ShowMessage('Unable to get access to WinInet.Dll');
    Result := False;
    Exit;
  end;
  { Connect to the FTP Server }
  hFTP := InternetConnect(hNet, // Handle from InternetOpen
                          PChar(strHost), // FTP server
                          port, // (INTERNET_DEFAULT_FTP_PORT),
                          PChar(StrUser), // username
                          PChar(strPwd),  // password
                          INTERNET_SERVICE_FTP, // FTP, HTTP, or Gopher?
                          0, // flag: 0 or INTERNET_FLAG_PASSIVE
                          0);// User defined number for callback
  if hFTP = nil then
  begin
    InternetCloseHandle(hNet);
    //ShowMessage(Format('Host "%s" is not available',[strHost]));
    Result := False;
    Exit;
  end;
  { Change directory }
  bSuccess := FtpSetCurrentDirectory(hFTP, PChar(ftpDir));
  if not bSuccess then
  begin
    InternetCloseHandle(hFTP);
    InternetCloseHandle(hNet);
    Result := False;
    //ShowMessage(Format('Cannot set directory to %s.',[ftpDir]));
    Exit;
  end;
  { Read size of file }
  if FtpFindFirstFile(hFTP, PChar(ftpFile), sRec, 0, 0) <> nil then
  begin
    fileSize := sRec.nFileSizeLow;
    // fileLastWritetime := sRec.lastWriteTime
  end else
  begin
    InternetCloseHandle(hFTP);
    InternetCloseHandle(hNet);
    Result := False;
    //ShowMessage(Format('Cannot find file ',[ftpFile]));
    Exit;
  end;
  { Open the file }
  hFile := FtpOpenFile(hFTP, // Handle to the ftp session
                       PChar(ftpFile), // filename
                       GENERIC_READ, // dwAccess
                       FTP_TRANSFER_TYPE_BINARY, // dwFlags
                       0); // This is the context used for callbacks.
  if hFile = nil then
  begin
    InternetCloseHandle(hFTP);
    InternetCloseHandle(hNet);
    Exit;
  end;
  { Create a new local file }
  AssignFile(LocalFile, TargetFile);
  {$i-}
  Rewrite(LocalFile, 1);
  {$i+}
  if IOResult <> 0 then
  begin
    InternetCloseHandle(hFile);
    InternetCloseHandle(hFTP);
    InternetCloseHandle(hNet);
    Exit;
  end;
  dwBytesRead := 0;
  bufsize := READ_BUFFERSIZE;
  while (bufsize > 0) do
  begin
    Application.ProcessMessages;
    if not InternetReadFile(hFile,
                            @buffer, // address of a buffer that receives the data
                            READ_BUFFERSIZE, // number of bytes to read from the file
                            bufsize) then Break; // receives the actual number of bytes read
    if (bufsize > 0) and (bufsize <= READ_BUFFERSIZE) then
      BlockWrite(LocalFile, buffer, bufsize);
    dwBytesRead := dwBytesRead + bufsize;
    { Show Progress }
    ProgressBar.Position := Round(dwBytesRead * 100 / fileSize);
    //Form3.Label1.Caption := Format('%s of %s / %d %%',[FmtFileSize(dwBytesRead),FmtFileSize(fileSize) ,ProgressBar.Position]);
  end;
  CloseFile(LocalFile);
  InternetCloseHandle(hFile);
  InternetCloseHandle(hFTP);
  InternetCloseHandle(hNet);
  Result := True;
end;

end.
