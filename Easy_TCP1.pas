unit Easy_TCP1;
// Description : TCP/IP Client and Server Unit
// ObjectOriented/Class, Delphi7/Win32API
// Revisions : 1.5 - Improved error messages and error checking      21-Nov-2006
//             1.4 - Fixed Connection Timeout Bug
//                   Various Other Bugfixes
//                   Improved Server Performances and Memory Usage   20-Dec-2005
//             1.3 - Fixed an ETCPClientSocket Addressing Bug        26-Nov-2005
//             1.2 - Improved Error Detection/Feedback               29-Oct-2005
//             1.1 - Added Per-Client Buffering                      29-Oct-2005
//             1.0 - Original Release                                23-Oct-2005
// By : Emmanuel Charette - emmanc@hotmail.com   
//
// How to use the server : 
// Call YourSocket := TCPServerSocket.Create; to create the socket.
// Set the OnReceive, OnError, OnConnect and OnDisconnect event property.
// Call YourSocket.Listen(<port number>); to initiate the listening.
// SendData/BroadcastData to send to the specified client or every connected clients.
// BroadcastDataExcept will send to every clients except the specified one.
// The buffer need to be a variable that will exists for the duration of the send.
// Disconnect/DisconnectAll to drop a connection or all of them.
// *** Don't forget to call "Destroy" to clear the socket and the object.
// Otherwise WinSock will think the socket is always active.
//
// Clients are refered to as IDs, which are their indices in the ClientList
// Disconnected clients are removed from the list and the following clients are
// "bubbled" up to fill the spot, hence changing their respective ID.
//
//
// How to use the client : 
// Call YourSocket := TCPClientSocket.Create; to create the socket.
// Set the OnReceive, OnError, OnConnect and OnDisconnect event property.
// Call YourSocket.Connect(<host name>, <port number>); to connect to the server.
// Note : Connection is asynchronous, there is a 5 seconds timeout on connection attempts.
// Use SendData to send data to the server,
// The buffer need to be a variable that will exists for the duration of the send.
// Disconnect to drop the connection
// Destroy to clear the socket and the object.


interface

uses WinSock, Windows, Classes, Sysutils, Messages;

const
  ETCP_Required_Version = $101;  //Required WinSock version
  ETCP_Message = WM_USER + 124;  //Custom WinMessage for Async sockets
  ETCP_MaxLength = 8192;         //Maximum buffer length (Typical)
  ETCP_MaxClients = 256;         //Maximun number of clients accepted per server
  ETCP_ConnectTimeOut = 5000;    //Connection time-out in ms

type    
  ETCPBuffer = array[0..ETCP_MaxLength-1] of byte; //Receive buffer type
  ETCPPBuffer = ^ETCPBuffer;

  ETCPClientRecord = record
    Socket: integer;         //winsock socket handle
    Host: string;            //hostname
    Port: word;              //remote port
    RBuffer: ETCPPBuffer;    //Receive buffer pointer
  end;

  ETCPOnError = procedure(Msg: String);

  ETCPServerOnReceive = procedure(ID: integer; Buffer: ETCPBuffer; Size: integer);
  ETCPServerOnConnect = procedure(ID: integer);
  ETCPServerOnDisconnect = procedure(ID: integer; ClientRecord: ETCPClientRecord);

  ETCPClientOnReceive = procedure(Buffer: ETCPBuffer; Size: integer);
  ETCPClientOnConnect = procedure;
  ETCPClientOnDisconnect = procedure;

  ETCPServerSocket = class
    private
      fOnReceive: ETCPServerOnReceive;
      fOnError: ETCPOnError;
      fOnConnect: ETCPServerOnConnect;
      fOnDisconnect: ETCPServerOnDisconnect;

      Message_Handle: HWND;
      Socket_Data: WSADATA;
      Socket_IsBound: Boolean;
      Socket_Handle: Integer;
      Last_Disconnect: ETCPClientRecord;

      procedure Message_Procedure(var Message: TMessage);
      function  AddClient(Socket: integer; Host: string; Port: word):integer;
      procedure DelClient(ID: integer);
      function  FindID(Socket: integer):integer;

    public
      MaxLength: integer;//Maximum buffer length from socket options
      NumClients: integer;//Current number of clients
      ClientList: array[1..ETCP_MaxClients] of ETCPClientRecord;

      constructor Create;
      destructor  Destroy; override;

      property OnReceive: ETCPServerOnReceive read fOnReceive write fOnReceive;
      property OnError: ETCPOnError read fOnError write fOnError;
      property OnConnect: ETCPServerOnConnect read fOnConnect write fOnConnect;
      property OnDisconnect: ETCPServerOnDisconnect read fOnDisconnect write fOnDisconnect;

      procedure Listen(Port: Word);
      function  SendData(ID: integer; var Buffer; Size: integer):integer;
      function  BroadcastData(var Buffer; Size: integer):integer;
      function  BroadcastDataExcept(ID: integer; var Buffer; Size: integer):integer;
      procedure Disconnect(ID: integer);
      procedure DisconnectAll;
  end;

  ETCPClientSocket = class
    private
      fOnReceive: ETCPClientOnReceive;
      fOnError: ETCPOnError;
      fOnConnect: ETCPClientOnConnect;
      fOnDisconnect: ETCPClientOnDisconnect;

      Message_Handle: HWND;
      Socket_Data: WSADATA;
      Socket_IsBound: Boolean;
      Socket_Connected: boolean;
      Socket_Handle: Integer;

      RBuffer: ETCPBuffer; //Receive buffer
      procedure Message_Procedure(var Message: TMessage);

    public
      MaxLength: integer;//Maximum buffer length from socket options

      constructor Create;
      destructor  Destroy; override;

      property OnConnect: ETCPClientOnConnect read fOnConnect write fOnConnect;
      property OnDisconnect: ETCPClientOnDisconnect read fOnDisconnect write fOnDisconnect;
      property OnReceive: ETCPClientOnReceive read fOnReceive write fOnReceive;
      property OnError: ETCPOnError read fOnError write fOnError;

      procedure Connect(Host: string; Port: word);
      function  Connected:boolean;
      procedure Disconnect;
      function  SendData(var Buffer; Size: integer):integer;
  end;




//Avoid the notorious "if Assigned" at each and every single lines of code.
procedure DefaultOnError(Msg: String);
procedure DefaultOnReceiveSrv(ID: integer; Buffer: ETCPBuffer; Size: integer);
procedure DefaultOnDisconnectSrv(ID: integer; ClientRecord: ETCPClientRecord);
procedure DefaultOnReceive(Buffer: ETCPBuffer; Size: integer);
procedure DefaultDummySrv(ID: integer);
procedure DefaultDummy;

//Helpers functions
function  WinSockErrorToString(Err: integer):string;
function  IntToIP(Addr: integer):string;
procedure DNSLookup(Address: string; HostName, IP: string);
function  Get_Inet_Addr(Addr: string):integer;


implementation

// Easy TCP Server

constructor ETCPServerSocket.Create;

begin
  Socket_IsBound := False;
  OnReceive := DefaultOnReceiveSrv;
  OnError := DefaultOnError;
  OnConnect := DefaultDummySrv;
  OnDisconnect := DefaultOnDisconnectSrv;
  MaxLength := ETCP_MaxLength;
  Message_Handle := AllocateHWND(Message_Procedure);
  ZeroMemory(@ClientList,sizeof(ClientList));
  NumClients := 0;
end;

procedure ETCPServerSocket.Listen(Port: word);
var
  Error : integer;
  Socket_AddressInfo : TsockAddrIn;
  Option_Value : integer;
  Option_Length : integer;
begin
  Error := WSAStartup(ETCP_Required_Version, Socket_Data);
  if Error <> 0 then OnError('Listen: Invalid Winsock Version.') else begin
    FillChar(Socket_AddressInfo, SizeOf(Socket_AddressInfo), 0);
    Socket_AddressInfo.sin_family := AF_INET;
    Socket_AddressInfo.sin_port := htons(Port);
    Socket_AddressInfo.sin_addr.S_addr := 0;

    Socket_Handle := Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if Socket_Handle < 0 then OnError('Listen: Cannot Create Socket.') else begin
      if Bind(Socket_Handle, Socket_AddressInfo, SizeOf(Socket_AddressInfo)) = 0 then begin
        if WSAAsyncSelect(Socket_Handle, Message_Handle, ETCP_Message, FD_ACCEPT or FD_CONNECT or FD_READ or FD_CLOSE) = 0 then begin
          Socket_Isbound := True;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_SNDBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_RCVBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          if Winsock.listen(Socket_handle, SOMAXCONN) <> 0 then begin
            OnError('Listen: Cannot Initiate Listening.');
            CloseSocket(Socket_Handle);
            Socket_IsBound := False;
          end;

        end else begin
          OnError('Listen: Cannot Select Socket.');
          CloseSocket(Socket_Handle);
          Socket_IsBound := False;
        end; //End Select
      end else begin
        OnError('Listen: Cannot Bind Socket.');
        CloseSocket(Socket_Handle);
        Socket_IsBound := False;
      end; //End Bind
    end;  //End Socket
  end; //End Startup
end;


destructor ETCPServerSocket.Destroy;
begin
  if NumClients > 0 then DisconnectAll;
  if Socket_IsBound then CloseSocket(Socket_Handle);
  Socket_IsBound := False;
  WSACleanup;
  DeallocateHWnd(Message_Handle);
  inherited destroy;
end;

procedure ETCPServerSocket.Message_Procedure(var Message: TMessage);
var
  Size, CurrentSocket, CurrentID : integer;
  Socket_AddressInfo : TsockAddrIn;
  AI_Size : integer;  
begin
  if Message.Msg = ETCP_Message then case LoWord(Message.LParam) of

    FD_READ : begin
      AI_Size := SizeOf(Socket_AddressInfo);
      CurrentSocket := Message.WParam;
      CurrentID := FindID(CurrentSocket);
      if CurrentID > 0 then begin
        Size := RecvFrom(CurrentSocket, ClientList[CurrentID].RBuffer^, MaxLength, 0, Socket_AddressInfo, AI_Size);
        if Size < 0 then OnError('OnReceive: '+WinSockErrorToString(WSAGetLastError)) else OnReceive(CurrentID, ClientList[CurrentID].RBuffer^, Size);
      end else OnError('OnReceive: Unknown Socket.');
    end;

    FD_CLOSE : Begin
      CurrentID := FindID(Message.WParam);
      move(ClientList[CurrentID], Last_Disconnect, sizeof(ETCPClientRecord));
      DelClient(CurrentID);
      OnDisconnect(CurrentID, Last_Disconnect);
    end;

    FD_ACCEPT : begin
      AI_Size:= SizeOf(Socket_AddressInfo);
      CurrentSocket := Accept(Socket_Handle, @Socket_AddressInfo, @AI_Size);

      if NumClients < ETCP_MaxClients then begin
        OnConnect(AddClient(CurrentSocket, IntToIP(Socket_AddressInfo.sin_addr.s_Addr), ntohs(Socket_AddressInfo.sin_port)));
      end else begin
        OnError('OnConnect: Connection List is Full.');
        CloseSocket(CurrentSocket);
      end;
    end;  //End Accept

  end;  //End Case
end;

function ETCPServerSocket.SendData(ID: integer; var Buffer; Size: integer):integer;
begin
  Result := 0;
  if Socket_IsBound then begin
    if Size <= MaxLength then begin
      Result := Send(ClientList[ID].Socket, Buffer, Size, 0);
      if Result < 0 then begin
        OnError('SendData: '+WinSockErrorToString(Result));
        Result := 0;
      end;
    end else OnError('SendData: Packet Too Big ('+inttostr(MaxLength)+' Bytes Max).');
  end else OnError('SendData: Socket Not Bound.');
end;

function ETCPServerSocket.BroadcastData(var Buffer; Size: integer):integer;
var l1, Sent : integer;
begin
  Result := 0;
  if Socket_IsBound then begin
    if Size <= MaxLength then begin
      for l1 := 1 to NumClients do if (ClientList[l1].Socket <> 0) then begin
        Sent := Send(ClientList[l1].Socket, Buffer, Size, 0);
        if Sent < 0 then OnError(WinSockErrorToString(Result)) else Result := Result + Sent;
      end;
    end else OnError('BroadcastData: Packet Too Big ('+inttostr(MaxLength)+' Bytes Max).');
  end else OnError('BroadcastData: Socket Not Bound.');
end;

function ETCPServerSocket.BroadcastDataExcept(ID: integer; var Buffer; Size: integer):integer;
var l1, Sent : integer;
begin
  Result := 0;
  if Socket_IsBound then begin
    if Size <= MaxLength then begin
      for l1 := 1 to NumClients do if (ClientList[l1].Socket <> 0) and (l1 <> ID) then begin
        Sent := Send(ClientList[l1].Socket, Buffer, Size, 0);
        if Sent < 0 then OnError(WinSockErrorToString(Result)) else Result := Result + Sent;
      end;
    end else OnError('BroadcastDataExcept: Packet Too Big ('+inttostr(MaxLength)+' Bytes Max).');
  end else OnError('BroadcastDataExcept: Socket Not Bound.');
end;

procedure ETCPServerSocket.Disconnect(ID: integer);
begin
  if ClientList[ID].Socket <> 0 then begin
    CloseSocket(ClientList[ID].Socket);
    move(ClientList[ID], Last_Disconnect, sizeof(ETCPClientRecord));
    DelClient(ID);
    OnDisconnect(ID, Last_Disconnect);
  end;
end;

procedure ETCPServerSocket.DisconnectAll;
var l1 : integer;
begin
  for l1 := NumClients downto 1 do if ClientList[1].Socket <> 0 then begin
    CloseSocket(ClientList[l1].Socket);
    move(ClientList[l1], Last_Disconnect, sizeof(ETCPClientRecord));
    DelClient(l1);
    OnDisconnect(l1, Last_Disconnect);
  end;
end;

function ETCPServerSocket.AddClient(Socket: integer; Host: string; Port : word):integer;
begin  //New Clients are always added at the end of the list.
  inc(NumClients);
  Zeromemory(@ClientList[NumClients], sizeof(ETCPClientRecord));
  New(ClientList[NumClients].RBuffer);
  ClientList[NumClients].Host := Host;
  ClientList[NumClients].Port := Port;
  ClientList[NumClients].Socket := Socket;
  Result := NumClients;
end;

procedure ETCPServerSocket.DelClient(ID: integer);
var l1 : integer;
begin
  if (ID > 0) and (ID <= NumClients) then begin
    //Clear Data
    Dispose(ClientList[ID].RBuffer);
    Zeromemory(@ClientList[ID], sizeof(ETCPClientRecord));
    //if not the last one on the list bubble down the following clients.
    if ID < NumClients then for l1 := ID to Numclients-1 do move(ClientList[l1+1],ClientList[l1],SizeOf(ETCPClientRecord));
    dec(NumClients);
  end else OnError('OnDisconnect: Unknown Socket.');
end;

function  ETCPServerSocket.FindID(Socket: integer):integer;
var l1 : integer;
begin
  Result := 0;
  for l1 := 1 to NumClients do if Socket = ClientList[l1].Socket then Result := l1;
end;




// Easy TCP Client

constructor ETCPClientSocket.Create;
begin
  Socket_IsBound := False;
  Socket_Connected := False;
  OnReceive := DefaultOnReceive;
  OnError := DefaultOnError;
  OnConnect := DefaultDummy;
  OnDisconnect := DefaultDummy;
  MaxLength := ETCP_MaxLength;
  Message_Handle := AllocateHWND(Message_Procedure);
end;


procedure ETCPClientSocket.Message_Procedure(var Message: TMessage);
var
  Size : integer;
begin
  if Message.Msg = ETCP_Message then case Message.LParamLo of
    FD_READ : begin
      Size := Recv(Socket_Handle,RBuffer,MaxLength,0);
      if Size < 0 then OnError('OnReceive: '+WinSockErrorToString(WSAGetLastError)) else OnReceive(RBuffer, Size);
    end;
    FD_CLOSE : begin
      KillTimer(Message_Handle, ETCP_Message);
      Socket_Connected := false;
      OnDisconnect;
    end;
    FD_CONNECT : begin
      KillTimer(Message_Handle, ETCP_Message);
      Socket_Connected := true;
      OnConnect;
    end;
  end;
  if (Message.Msg = ETCP_Message) and (Message.LParamHi <> 0) then OnError('HiLParam Error '+inttostr(Message.LParamHi));
  if Message.Msg = WM_Timer then begin
    KillTimer(Message_Handle, ETCP_Message);
    if not Socket_Connected then OnError('Connect: Connection Timed-out.');
  end;
end;

      
destructor ETCPClientSocket.Destroy;
begin
  Disconnect;
  WSACleanup;
  DeallocateHWnd(Message_Handle);
  inherited destroy;
end;


Procedure ETCPClientSocket.Connect(Host: string; Port: word);
var
  Error : integer;
  Socket_AddressInfo : TsockAddrIn;
  Option_Value : integer;
  Option_Length : integer;
begin
if not Socket_Connected then begin
  Error := WSAStartup(ETCP_Required_Version, Socket_Data);
  if Error <> 0 then OnError('Connect: Invalid Winsock Version.') else begin
    FillChar(Socket_AddressInfo,SizeOf(Socket_AddressInfo),0);
    Socket_AddressInfo.sin_family := AF_INET;
    Socket_AddressInfo.sin_port := 0;
    Socket_AddressInfo.sin_addr.S_addr := 0;
    Socket_Handle := Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if Socket_Handle < 0 then OnError('Connect: Cannot Create Socket.') else begin
      if Bind(Socket_Handle, Socket_AddressInfo, SizeOf(Socket_AddressInfo)) = 0 then begin
        if WSAAsyncSelect(Socket_Handle, Message_Handle, ETCP_Message, FD_CONNECT or FD_READ or FD_CLOSE) = 0 then begin
          Socket_Isbound := True;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_SNDBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          Option_Length := 4;
          GetSockOpt(Socket_Handle, SOL_SOCKET, SO_RCVBUF, @Option_Value, Option_Length);
          if Option_Length = 4 then if Option_Value < MaxLength then MaxLength := Option_Value;

          FillChar(Socket_AddressInfo,SizeOf(Socket_AddressInfo),0); //Connect
          Socket_AddressInfo.sin_family := AF_INET;
          Socket_AddressInfo.sin_port := htons(port);
          Socket_AddressInfo.sin_addr.S_addr := Get_Inet_Addr(Host);
          if Socket_AddressInfo.sin_addr.S_addr <> -1 then begin
            Winsock.connect(Socket_Handle,Socket_AddressInfo, SizeOf(Socket_AddressInfo));
            Socket_Connected := false;
            SetTimer(Message_Handle, ETCP_Message, ETCP_ConnectTimeOut, nil);
          end else OnError('Connect: Host Not Found.');

        end else begin
          OnError('Connect: Cannot Select Socket.');
          CloseSocket(Socket_Handle);
          Socket_IsBound := False;
        end; //End Select
      end else begin
        OnError('Connect: Cannot Bind Socket.');
        CloseSocket(Socket_Handle);
        Socket_IsBound := False;
      end; //End Bind
    end;  //End Socket
   end; //End Startup
end else OnError('Connect: Already Connected.');
end;

function ETCPClientSocket.Connected:boolean;
begin
  if Socket_Connected and Socket_Isbound then Result := True else Result := False;
end;

procedure ETCPClientSocket.Disconnect;
begin
  if Socket_Isbound then begin
    CloseSocket(Socket_Handle);
    Socket_Isbound := false;
    if Socket_Connected then OnDisconnect;
    Socket_Connected := false;
  end;
end;


function  ETCPClientSocket.SendData(var Buffer; Size: integer):integer;
begin
  Result := 0;
  if Socket_IsBound and Socket_Connected then begin
    if Size <= MaxLength then begin
      Result := Send(Socket_Handle, Buffer, Size, 0);
      if Result < 0 then begin
        OnError('SendData: '+WinSockErrorToString(Result));
        Result := 0;
      end;
    end else OnError('SendData: Packet Too Big ('+inttostr(MaxLength)+' Bytes Max).');
  end else OnError('SendData: Socket Not Bound.');

end;


































procedure DefaultDummySrv(ID: integer);
begin
  //Not much to do here.
  //Just dont want to use an "If Assigned" at every line
end;

procedure DefaultDummy;
begin
  //Kinda boring.
  //same explanation goes here...
end;

procedure DefaultOnReceiveSrv(ID: integer; Buffer: ETCPBuffer; Size: integer);
begin
  MessageBox(0,pchar('Data Received'+#13+'OnReiceive not Assigned'+#13+'Size: '+inttostr(size)),'Easy_TCP',MB_OK);
end;

procedure DefaultOnReceive(Buffer: ETCPBuffer; Size: integer);
begin
  MessageBox(0,pchar('Data Received'+#13+'OnReiceive not Assigned'+#13+'Size: '+inttostr(size)),'Easy_TCP',MB_OK);
end;

procedure DefaultOnError(Msg: String);
begin
  MessageBox(0,pchar('Error:'+#13+Msg),'Easy_TCP',MB_OK);
end;

procedure DefaultOnDisconnectSrv(ID: integer; ClientRecord: ETCPClientRecord);
begin
 // heh !
end;

function IntToIP(Addr: integer):string;
begin
  Result := inttostr( addr and $FF) + '.' +
            inttostr((addr and $FF00) shr 8) + '.' +
            inttostr((addr and $FF0000) shr 16) + '.' +
            inttostr((addr and $FF000000) shr 24);
end;

procedure DNSLookup(Address: string; HostName, IP: string);
var Host_Info : PHostEnt;
    IPBuffer : Integer;
begin
  IPBuffer := inet_addr(pchar(Address));
  if IPBuffer = INADDR_NONE then begin
    Host_Info := GetHostByName(pchar(Address));
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

function Get_Inet_Addr(Addr: string):integer;
var Host_Info : PHostEnt;
    iBuffer : integer;
begin
  iBuffer := inet_addr(pchar(Addr));
  if iBuffer = INADDR_NONE then begin
    Host_Info := GetHostByName(pchar(Addr));
    if Host_Info <> nil then move(Host_Info.h_addr_list^^,iBuffer,4);
  end;
  Result := iBuffer;
end;

function WinSockErrorToString(Err: integer):string;
// By Gary T. Desrosiers
begin
 case Err of
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
    else result := 'Not a WinSock error ('+inttostr(Err)+')';
    Result := Result + '.';
  end;
end;

end.

