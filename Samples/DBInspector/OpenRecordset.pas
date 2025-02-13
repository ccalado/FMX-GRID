unit OpenRecordset;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Memo.Types, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.FMXUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.UI, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  FMX.Layouts, ADato.FMX.Controls.ScrollableControl.Impl,
  ADato.FMX.Controls.ScrollableRowControl.Impl, ADato.Controls.FMX.Tree.Impl,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, System.Actions,
  FMX.ActnList, Delphi.Extensions.VirtualDataset,
  ADato.Data.VirtualDatasetDataModel, ADato.Data.DatasetDataModel,
  System.Diagnostics, FMX.ListBox, System_, ADato.Controls.FMX.Tree.Intf,
  FMX.DataControl.ScrollableControl, FMX.DataControl.ScrollableRowControl,
  FMX.DataControl.Static, FMX.DataControl.Editable, FMX.DataControl.Impl,
  FMX.DataControl.Events;

type
  TOpenRecordSetFrame = class(TFrame)
    SqlQuery: TMemo;
    Layout1: TLayout;
    splitSqlSourcePanel: TSplitter;
    DataEditor: TMemo;
    fdConnection: TFDConnection;
    TheQuery: TFDQuery;
    DataSource1: TDataSource;
    Logging: TMemo;
    ActionList1: TActionList;
    btnExecute: TSpeedButton;
    DatasetDataModel1: TDatasetDataModel;
    Button1: TButton;
    acAbort: TAction;
    SpeedButton2: TSpeedButton;
    acNextRecordSet: TAction;
    lblConnection: TLabel;
    lyDataPanel: TLayout;
    Splitter2: TSplitter;
    cbRecordCount: TComboBox;
    Label1: TLabel;
    lblExecutionLog: TLabel;
    lblCellEditor: TLabel;
    DataGrid: TDataControl;
    lyCellEditor: TLayout;
    lyExecutionLog: TLayout;
    acExecute: TAction;
    procedure acAbortExecute(Sender: TObject);
    procedure acExecuteExecute(Sender: TObject);
    procedure acNextRecordSetExecute(Sender: TObject);
    procedure ActionList1Update(Action: TBasicAction; var Handled: Boolean);
    procedure DataEditorChangeTracking(Sender: TObject);
    procedure DataEditorKeyDown(Sender: TObject; var Key: Word; var KeyChar:
        WideChar; Shift: TShiftState);
    procedure DataGridCellChanged(const Sender: TObject; e: DCCellChangedEventArgs);
    procedure DataGridEditStart(const Sender: TObject; e: StartEditEventArgs);
    procedure TheQueryAfterCancel(DataSet: TDataSet);

  private
    FStopWatch: TStopWatch;
    FQueryEditorHeight: Single;

    function  get_ConnectionName: string;
    procedure set_ConnectionName(const Value: string);
    function  get_CommandText: string;
    procedure set_CommandText(const Value: string);

    procedure set_SqlSourceText(const Value: string);
    procedure AddMessage(AMessage: string);

  protected
    procedure UpdateDialogControls(IsSqlSourceWindow: Boolean);

  public
    { Public declarations }
    procedure ExecuteQuery(OpenNextRecordSet: Boolean);
    property ConnectionName: string read get_ConnectionName write set_ConnectionName;
    property CommandText: string read get_CommandText write set_CommandText;
    property SqlSourceText: string read get_CommandText write set_SqlSourceText;
  end;

implementation

uses
  System.TypInfo, ADato.Data.DataModel.intf, System.Collections;

{$R *.fmx}

procedure TOpenRecordSetFrame.acAbortExecute(Sender: TObject);
begin
  TheQuery.AbortJob;
end;

procedure TOpenRecordSetFrame.acExecuteExecute(Sender: TObject);
begin
  ExecuteQuery(False);
end;

procedure TOpenRecordSetFrame.acNextRecordSetExecute(Sender: TObject);
begin
  ExecuteQuery(True {Open next record set});
end;

procedure TOpenRecordSetFrame.ActionList1Update(Action: TBasicAction; var
    Handled: Boolean);
begin
  Handled := True;
  lblCellEditor.Visible := not DataEditor.IsFocused;
  lblExecutionLog.Visible := not Logging.IsFocused;

  acExecute.Enabled := not (TheQuery.Command.State in [csExecuting, csFetching]);
  acAbort.Enabled := TheQuery.Command.State in [csExecuting, csFetching];
end;

procedure TOpenRecordSetFrame.AddMessage(AMessage: string);
begin
  TThread.Queue(nil, procedure begin
    Logging.Lines.Add(AMessage);
  end);
end;

procedure TOpenRecordSetFrame.DataEditorChangeTracking(Sender: TObject);
begin
//  DataGrid.BeginEdit;
//  DataGrid.EditActiveCell(False);
//  DataGrid.Editor.Value := DataEditor.Lines.Text;
end;

procedure TOpenRecordSetFrame.DataEditorKeyDown(Sender: TObject; var Key: Word;
    var KeyChar: WideChar; Shift: TShiftState);

begin
//  if Key = vkReturn then
//  begin
//    DataGrid.EndEdit(True);
//    Key := 0;
//  end;
//
//  if Key = vkEscape then
//  begin
//    DataGrid.CancelEdit;
//    Key := 0;
//  end;
end;

procedure TOpenRecordSetFrame.DataGridCellChanged(const Sender: TObject; e: DCCellChangedEventArgs);
begin
  var s: string := '';

  DataEditor.OnChangeTracking := nil;
  try
    if e.NewCell <> nil then
    begin
      var p := e.NewCell.Column.PropertyName;
      if not CString.IsNullOrEmpty(p) then
      begin
        var f := DatasetDataModel1.FieldByName(p);
        if f <> nil then
        begin
          s := f.AsString;

          if f.CanModify then
          begin
            lblCellEditor.Text := 'Cell editor';
            DataEditor.ReadOnly := False;
          end
          else
          begin
            lblCellEditor.Text := 'Cell editor (read only)';
            DataEditor.ReadOnly := True;
          end;
        end;
      end;
    end;

    DataEditor.Lines.Text := s;
  finally
    DataEditor.OnChangeTracking := DataEditorChangeTracking;
  end;
end;

procedure TOpenRecordSetFrame.DataGridEditStart(const Sender: TObject; e: StartEditEventArgs);
begin
  e.MultilineEdit := True;
end;

procedure TOpenRecordSetFrame.ExecuteQuery(OpenNextRecordSet: Boolean);
begin
  FStopWatch := TStopwatch.StartNew;

  Logging.Lines.Clear;
  Logging.Visible := True;

  fdConnection.ResourceOptions.ServerOutput := True;

  var recCount: Integer;
  if Integer.TryParse(cbRecordCount.Text, recCount) then
    TheQuery.FetchOptions.RecsMax := recCount else
    TheQuery.FetchOptions.RecsMax := -1;

  TheQuery.ResourceOptions.CmdExecMode := amBlocking;

  // DataGrid.DataList := nil;
  DatasetDataModel1.Close;

  if not OpenNextRecordSet then
  begin
    TheQuery.FetchOptions.AutoClose := False;
    TheQuery.Close;

    if SqlQuery.Visible then
      TheQuery.SQL.Text := SqlQuery.Lines.Text;
  end;

  TThread.CreateAnonymousThread(procedure begin
    try
      if OpenNextRecordSet then
        TheQuery.NextRecordSet else
        TheQuery.Open;
    except
      on E: Exception do
        AddMessage(E.Message);
    end;

    TThread.Queue(nil, procedure begin

      // Not all queries return a dataset
      if TheQuery.Active then
      begin
        DatasetDataModel1.Open;
        DataGrid.DataList := (DatasetDataModel1 as IDataModel) as IList;
      end;

      if fdConnection.Messages <> nil then
      begin
        for var i := 0 to fdConnection.Messages.ErrorCount - 1 do
          AddMessage(fdConnection.Messages[i].Message);
      end;

      AddMessage(string.Format('Ready: %d ms', [FStopWatch.ElapsedMilliseconds]));
    end);
  end).Start;
end;

{ TOpenRecordSetFrame }

function TOpenRecordSetFrame.get_CommandText: string;
begin
  Result := SqlQuery.Text;
end;

function TOpenRecordSetFrame.get_ConnectionName: string;
begin
  Result := lblConnection.Text;
end;

procedure TOpenRecordSetFrame.set_CommandText(const Value: string);
begin
  UpdateDialogControls(False);
  SqlQuery.Text := Value;
end;

procedure TOpenRecordSetFrame.set_ConnectionName(const Value: string);
begin
  lblConnection.Text := Value;
end;

procedure TOpenRecordSetFrame.set_SqlSourceText(const Value: string);
begin
  UpdateDialogControls(True);
  SqlQuery.Text := Value;
end;

procedure TOpenRecordSetFrame.TheQueryAfterCancel(DataSet: TDataSet);
begin
  AddMessage('Canceled');
end;

procedure TOpenRecordSetFrame.UpdateDialogControls(IsSqlSourceWindow: Boolean);
begin
  // Hide data grid, go into Sql source editor mode
  if IsSqlSourceWindow then
  begin
    splitSqlSourcePanel.Visible := False;
    lyDataPanel.Visible := False;
    FQueryEditorHeight := SqlQuery.Height;
    SqlQuery.Align := TAlignLayout.Client;
  end
  else
  begin
    SqlQuery.Align := TAlignLayout.Top;
    if FQueryEditorHeight > 0 then
      SqlQuery.Height := FQueryEditorHeight;

    splitSqlSourcePanel.Visible := True;
    lyDataPanel.Visible := True;
  end;

end;

end.
