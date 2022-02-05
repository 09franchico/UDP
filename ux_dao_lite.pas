unit ux_dao_lite;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ZDataset;

{-----------------------------------------------------------------------------}
   Function ux_lite_sql(SqlTexto:string):string;
   Function ux_lite_sqlInsert(SqlText,param:string;param2:integer):string;

{-----------------------------------------------------------------------------}

implementation

uses
  DM, ux_log;


{-----------------------------------------------------------------------------}
Function ux_lite_sql(SqlTexto:string):string;
var
 Query:TZquery;
begin
     try

       query:=TZQuery.Create(nil);
       Query.Connection:=DataModule1.ZConn;
       query.Active;

       with query do
       begin
         close;
         SQL.Clear;
         SQL.Text:=SqlTexto;
         open;
         First;
       end;
       if Query.RecordCount <>0 then
       begin
          Result:=query.FieldByName('nome').Value;
       end;

     Except
      on E:Exception do
         ux_log_Text('SQL: '+E.Message);
     end;

end;
{------------------------------------------------------------------------------}

Function ux_lite_sqlInsert(SqlText,param:string;param2:integer):string;
var
 Query:TZquery;
begin

   try

    query:=TZQuery.Create(nil);
    Query.Connection:=DataModule1.ZConn;
    query.Active;
      with query do
      begin
        close;
        SQL.Clear;
        SQL.Text:=SqlText;
        ParamByName('p1').AsString:=param;
        ParamByName('p2').Asinteger:=param2;
        ExecSQL;
      end;
      if query.RowsAffected <>0 then
      begin
        result:='ok';
      end;
   except
   on E:Exception do
     ux_log_Text('SqlInsert:'+E.Message);
   end;

end;
end.
