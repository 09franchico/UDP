object DataModule1: TDataModule1
  OldCreateOrder = False
  Height = 360
  Width = 446
  object ZConn: TZConnection
    ControlsCodePage = cCP_UTF16
    Catalog = ''
    Properties.Strings = (
      'controls_cp=CP_UTF16')
    Connected = True
    HostName = ''
    Port = 0
    Database = 
      'C:\Users\Francisco\Desktop\DESENVOLVIMENTO\DELPHI\UDP\Win32\Debu' +
      'g\DB\outro.db'
    User = ''
    Password = ''
    Protocol = 'sqlite-3'
    LibraryLocation = 
      'C:\Users\Francisco\Desktop\DESENVOLVIMENTO\DELPHI\UDP\Win32\Debu' +
      'g\sqlite3.dll'
    Left = 64
    Top = 40
  end
  object QryNome: TZQuery
    Connection = ZConn
    SQL.Strings = (
      'Select * from tb_nome')
    Params = <>
    Left = 264
    Top = 48
  end
end
