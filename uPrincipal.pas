unit uPrincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Easy_UDP1, Data.DB,
  ZAbstractRODataset, ZAbstractDataset, ZDataset;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Edit1: TEdit;
    Button3: TButton;
    Label1: TLabel;
    Edit2: TEdit;
    Label2: TLabel;
    Edit3: TEdit;
    Label3: TLabel;
    verificar: TButton;
    ZQuery1: TZQuery;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure verificarClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  udsp_network, uFra_Global, ux_dao_lite;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  if SA_COMREMOTO_Inicializar = true then
  begin
    ShowMessage('Inicializado com sucesso!!');
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
   if SA_COMREMOTO_Finalizar = true then
   begin
      ShowMessage('Finalizado!!');
   end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  ip:string;
  porta:integer;
  Texto:string;
begin
   porta:=StrToInt(Edit1.Text);
   ip:=Edit2.Text;
   texto:=Edit3.Text;
  SA_COMREMOTO_EnviaDados(ip,porta,texto);

end;

procedure TForm1.verificarClick(Sender: TObject);
begin
   if vCom_Confirma then
   begin

   end;

end;

end.
