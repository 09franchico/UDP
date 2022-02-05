object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 299
  ClientWidth = 463
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 123
    Width = 26
    Height = 13
    Caption = 'Porta'
  end
  object Label2: TLabel
    Left = 24
    Top = 182
    Width = 10
    Height = 13
    Caption = 'Ip'
  end
  object Label3: TLabel
    Left = 24
    Top = 251
    Width = 26
    Height = 13
    Caption = 'texto'
  end
  object Button1: TButton
    Left = 24
    Top = 25
    Width = 161
    Height = 25
    Caption = 'Inicializar'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 24
    Top = 64
    Width = 161
    Height = 25
    Caption = 'Finalizar'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Edit1: TEdit
    Left = 24
    Top = 142
    Width = 73
    Height = 21
    TabOrder = 2
  end
  object Button3: TButton
    Left = 232
    Top = 266
    Width = 169
    Height = 25
    Caption = 'Enviar'
    TabOrder = 3
    OnClick = Button3Click
  end
  object Edit2: TEdit
    Left = 24
    Top = 201
    Width = 89
    Height = 21
    TabOrder = 4
  end
  object Edit3: TEdit
    Left = 24
    Top = 270
    Width = 185
    Height = 21
    TabOrder = 5
  end
  object verificar: TButton
    Left = 248
    Top = 216
    Width = 113
    Height = 25
    Caption = 'verificar'
    TabOrder = 6
    OnClick = verificarClick
  end
  object ZQuery1: TZQuery
    Params = <>
    Left = 304
    Top = 64
  end
end
