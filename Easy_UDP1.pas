unit Easy_UDP1;
// Description : UDP Datagram Unit
// ObjectOriented/Class, Delphi7/WinAPI
// Revisions : 1.3 - Added Broadcast function                        10-Mrs-2007
//             1.2 - New Create/Start procedure to handle errors     01-Dec-2006
//                 - Slightly improved error messages
//             1.1 - Improved Error Detection/Feedback               29-Oct-2005
//             1.0 - Original Release                                23-Oct-2005
// By : Emmanuel Charette - emmanc@hotmail.com
//
// Call YourSocket := EUDPSocket.Create to create the socket.
// Set the OnReceive and OnError event property.
// Call YourSocket.Start(<incoming data port number>) to initiate the socket.
// and use SendData to send to the specified UDP host/port.
// Broadcast will send the data to all connected hosts on either the LAN if "Local" is true
// or it will be routed by the modem or router. (it can go very very far so be careful)
// The buffer need to be a variable that will exists for the duration of the send.
// And that's it !
// Destroy to clear the socket and the object.


interface

uses WinSock, Windows, Classes, Sysutils,Messages;

const
  EUDP_Required_Version = $101;//Required WinSock version for UDP
  EUDP_Message = WM_USER + 123;//Custom WinMessage for Async sockets
  EUDP_MaxLength = 8192;       //Maximum buffer length

type

  EUDPBuffer = array[0..EUDP_MaxLength-1] of byte; //Receive buffer type

  EUDPOnReceive = procedure(Host: string; Port: word; const Buffer: EUDPBuffer; Size: integer);
  EUDPOnError = procedure(Msg: String);

  EUDPSocket = class
    private
      fOnReceive : EUDPOnReceive;
      fOnError : EUDPOnError;
      Message_Handle : HWND;
      Socket_Data : WSADATA;
      Socket_IsBound : Boolean;
      Socket_Handle : Integer;
      procedure Message_Procedure(var Message: TMessage);
    public
      MaxLength : integer; //Maximum buffer length from socket options
      Buffer : EUDPBuffer; //Receive buffer
      constructor Create;
      destructor Destroy; override;
      procedure Start(ListeningPort: Word);
      property OnReceive : EUDPOnReceive read fOnReceive write fOnReceive;
      property OnError : EUDPOnError read fOnError write fOnError;
      function SendData(Host: string; Port: word; var Buffer; Size: integer):integer;
      function Broadcast(Port: word; var Buffer; Size: integer; Local: boolean):integer;
  end;


//Helpers functions
procedure DefaultOnReceive(Host: string; Port: word; const Buffer : EUDPBuffer; Size: integer);
procedure DefaultOnError(Msg: String);
function WinSockErrorToString(err:integer):string;
function IntToIP(Addr : integer):string;
procedure DNSLookup(Address : string; var HostName, IP : string);
function Get_Inet_Addr(Addr : string):integer;


implementation




constructor EUDPSocket.Create;
begin
  Socket_IsBound := False;
  OnReceive := DefaultOnReceive;
  OnError := DefaultOnError;
  MaxLength := EUDP_MaxLength;
  Message_Handle := AllocateHWND(Message_Procedure);
end;

procedure EUDPSocket.Start(ListeningPort: word);
var
  Error : integer;
  Socket_AddressInfo : TsockAddrIn;
  Option_Value : integer;
  Option_Length : integer;
begin
  Error := WSAStartup(EUDP_Required_Version, Socket_Data);
  if Error <> 0 then OnError('Start: Invalid Winsock Version.') else begin

    Socket_AddressInfo.sin_family := AF_INET;
    Socket_AddressInfo.sin_port := htons(ListeningPort);
    Socket_AddressInfo.sin_addr.S_addr := 0;

    Socket_Handle := Socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if Socket_Handle < 0 then OnError('Start: Cannot Create Socket.') else begin
      if Bind(Socket_Handle, Socket_AddressInfo, SizeOf(Socket_AddressInfo)) = 0 then begin
        if WSAAsyncSelect(Socket_Handle, Message_Handle, EUDP_Message, FD_READ) = 0 then begin
          Socket_Isbound := True;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_SNDBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_RCVBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          Option_Length := 4;
          Option_Value :=-1;
          SetSockOpt(Socket_Handle, SOL_SOCKET, SO_BROADCAST, @Option_Value, Option_Length);

        end else begin
          OnError('Start: Cannot Select Socket.');
          CloseSocket(Socket_Handle);
          Socket_IsBound := False;
        end; //End Select
      end else begin
        OnError('Start: Cannot Bind Socket.');
        CloseSocket(Socket_Handle);
        Socket_IsBound := False;
      end; //End Bind
    end;  //End Socket
  end; //End Startup
end;

destructor EUDPSocket.Destroy;
begin
  if Socket_IsBound then CloseSocket(Socket_Handle);
  Socket_IsBound := False;
  WSACleanup;
  DeallocateHWnd(Message_Handle);
  inherited destroy;
end;

procedure EUDPSocket.Message_Procedure(var Message: TMessage);
var
  Size : integer;
  Socket_AddressInfo : TsockAddrIn;
  AI_Size : integer;
begin
  if Message.Msg = EUDP_Message then case LoWord(Message.LParam) of
    FD_READ : begin
       AI_Size:= SizeOf(Socket_AddressInfo);
       Size := RecvFrom(Socket_Handle,Buffer,MaxLength,0,Socket_AddressInfo,AI_Size);
       if Size < 0 then OnError('OnReceive: '+WinSockErrorToString(WSAGetLastError)) else
       OnReceive(IntToIP(Socket_AddressInfo.sin_addr.s_Addr),ntohs(Socket_AddressInfo.sin_port),Buffer,Size);
    end;
  end;
end;

function EUDPSocket.SendData(Host: string; Port: word; var Buffer; Size: integer):integer;
var
  Socket_AddressInfo : TsockAddrIn;
  AI_Size : integer;
begin
  Result := 0;
  if Host <> '' then begin
    if Socket_IsBound then begin
      if Size <= MaxLength then begin
        FillChar(Socket_AddressInfo,SizeOf(Socket_AddressInfo),0);
        Socket_AddressInfo.sin_family := AF_INET;
        Socket_AddressInfo.sin_port := htons(Port);
        Socket_AddressInfo.sin_addr.S_addr := Get_Inet_Addr(Host);
        if Socket_AddressInfo.sin_addr.S_addr = INADDR_NONE then OnError('SendData: Host Not Found.') else begin
          AI_Size := SizeOf(Socket_AddressInfo);
          Result := SendTo(Socket_handle,Buffer,Size,0,Socket_AddressInfo,AI_Size);
          if Result < 0 then begin
            OnError('SendData: '+WinSockErrorToString(Result));
            Result := 0;
          end;
        end;
      end else OnError('SendData: Packet Too Big ('+inttostr(MaxLength)+' Bytes Max).');
    end else OnError('SendData: Socket Not Bound.');
  end else OnError('SendData: No Host Specified.');
end;

function EUDPSocket.Broadcast(Port: word; var Buffer; Size: integer; Local: boolean):integer;
var
  Socket_AddressInfo : TsockAddrIn;
  AI_Size : integer;
begin
  Result := 0;
  if Socket_IsBound then begin
    if Size <= 512 then begin
      FillChar(Socket_AddressInfo,SizeOf(Socket_AddressInfo),0);
      Socket_AddressInfo.sin_family := AF_INET;
      Socket_AddressInfo.sin_port := htons(Port);
      Socket_AddressInfo.sin_addr.S_addr := INADDR_BROADCAST;
      AI_Size := SizeOf(Socket_AddressInfo);
      if Local then Result := SendTo(Socket_handle,Buffer,Size,MSG_DONTROUTE,Socket_AddressInfo,AI_Size) else
      Result := SendTo(Socket_handle,Buffer,Size,0,Socket_AddressInfo,AI_Size);
      if Result < 0 then begin
        OnError('Broadcast: '+WinSockErrorToString(Result));
        Result := 0;
      end;

    end else OnError('Broadcast: Packet Too Big (512 Bytes Max).');
  end else OnError('Broadcast: Socket Not Bound.');
end;

procedure DefaultOnReceive(Host:string; Port: word; const Buffer: EUDPBuffer; Size: integer);
begin
  MessageBox(0,pchar('Data Received'+#13+'OnReiceive not Assigned'+#13+'Host: '+Host+#13+'Port: '+inttostr(port)+#13+'Size: '+inttostr(size)),'Easy_UDP',MB_OK);
end;

procedure DefaultOnError(Msg : String);
begin
  MessageBox(0,pchar('Error:'+#13+Msg),'Easy_UDP',MB_OK);
end;
















function IntToIP(Addr : integer):string;
begin
  Result := inttostr( addr and $FF) + '.' +
            inttostr((addr and $FF00) shr 8) + '.' +
            inttostr((addr and $FF0000) shr 16) + '.' +
            inttostr((addr and $FF000000) shr 24);
end;


procedure DNSLookup(Address : string; var HostName, IP : string);
var Host_Info : PHostEnt;
    IPBuffer : Integer;
begin
  IPBuffer := inet_addr(Pansichar(Address));
  if IPBuffer = INADDR_NONE then begin
    Host_Info := GetHostByName(Pansichar(Address));
    if Host_Info <> nil then begin
      HostName := Address;
      move(Host_Info.h_addr_list^^,IPBuffer,4);
      IP := IntToIP(IPBuffer);
    end else begin
     IP := 'IP Not Found';
     HostName := 'HostName Not Found';
    end;
  end else begin
    IP := IntToIP(IPBuffer);
    HostName := 'HostName Not Found';
    Host_Info := GetHostByAddr(@IPBuffer,4,AF_INET);
    if Host_Info <> nil then HostName := StrPas(Host_Info.h_name);
  end;
end;


function Get_Inet_Addr(Addr : string):integer;
var Host_Info : PHostEnt;
    iBuffer : cardinal;
    pAddr : pAnsiChar;
begin
  pAddr := pansichar(AnsiString(Addr));
  iBuffer := inet_addr(pAddr);
  if iBuffer = INADDR_NONE then begin
    Host_Info := GetHostByName(pAddr);
    if Host_Info <> nil then move(Host_Info.h_addr_list^^,iBuffer,4);
  end;
  Result := iBuffer;
end;


function WinSockErrorToString(err:integer):string;
// By Gary T. Desrosiers
begin
 case err of
    WSAEINTR:      result := 'Interrupted system call';
    WSAEBADF:      result := 'Bad file number';
    WSAEACCES:      result := 'Permission denied';
    WSAEFAULT:      result := 'Bad address';
    WSAEINVAL:      result := 'Invalid argument';
    WSAEMFILE:      result := 'Too many open files';
    WSAEWOULDBLOCK:      result := 'Operation would block';
    WSAEINPROGRESS:      result := 'Operation now in progress';
    WSAEALREADY:      result := 'Operation already in progress';
    WSAENOTSOCK:      result := 'Socket operation on non-socket';
    WSAEDESTADDRREQ:      result := 'Destination address required';
    WSAEMSGSIZE:      result := 'Message too long';
    WSAEPROTOTYPE:      result := 'Protocol wrong type for socket';
    WSAENOPROTOOPT:      result := 'Protocol not available';
    WSAEPROTONOSUPPORT:      result := 'Protocol not supported';
    WSAESOCKTNOSUPPORT:      result := 'Socket type not supported';
    WSAEOPNOTSUPP:      result := 'Operation not supported on socket';
    WSAEPFNOSUPPORT:      result := 'Protocol family not supported';
    WSAEAFNOSUPPORT:      result := 'Address family not supported by protocol family';
    WSAEADDRINUSE:      result := 'Address already in use';
    WSAEADDRNOTAVAIL:      result := 'Can''t assign requested address';
    WSAENETDOWN:      result := 'Network is down';
    WSAENETUNREACH:      result := 'Network is unreachable';
    WSAENETRESET:      result := 'Network dropped connection on reset';
    WSAECONNABORTED:      result := 'Software caused connection abort';
    WSAECONNRESET:      result := 'Connection reset by peer';
    WSAENOBUFS:      result := 'No buffer space available';
    WSAEISCONN:      result := 'Socket is already connected';
    WSAENOTCONN:      result := 'Socket is not connected';
    WSAESHUTDOWN:      result := 'Can''t send after socket shutdown';
    WSAETOOMANYREFS:      result := 'Too many references: can''t splice';
    WSAETIMEDOUT:      result := 'Connection timed out';
    WSAECONNREFUSED:      result := 'Connection refused';
    WSAELOOP:      result := 'Too many levels of symbolic links';
    WSAENAMETOOLONG:      result := 'File name too long';
    WSAEHOSTDOWN:      result := 'Host is down';
    WSAEHOSTUNREACH:      result := 'No route to host';
    WSAENOTEMPTY:      result := 'Directory not empty';
    WSAEPROCLIM:      result := 'Too many processes';
    WSAEUSERS:      result := 'Too many users';
    WSAEDQUOT:      result := 'Disc quota exceeded';
    WSAESTALE:      result := 'Stale NFS file handle';
    WSAEREMOTE:      result := 'Too many levels of remote in path';
    WSASYSNOTREADY:      result := 'Network sub-system is unusable';
    WSAVERNOTSUPPORTED:      result := 'WinSock DLL cannot support this application';
    WSANOTINITIALISED:      result := 'WinSock not initialized';
    WSAHOST_NOT_FOUND:      result := 'Host not found';
    WSATRY_AGAIN:      result := 'Non-authoritative host not found';
    WSANO_RECOVERY:      result := 'Non-recoverable error';
    WSANO_DATA:      result := 'No Data';
    else result := 'Not a WinSock error';
    Result := Result + '.';
  end;
end;

end.
