unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, ComCtrls, Dialogs, ExtCtrls, FileUtil, Forms, Grids,
  IdAllFTPListParsers, IdAntiFreeze, IdComponent, IdFTP, IdFTPCommon,
  IdFTPList, sqldb, sqlite3conn,
  StdCtrls,
  SysUtils, Windows;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1:   TButton;
    Button2:   TButton;
    Button3:   TButton;
    Button4:   TButton;
    Button5:   TButton;
    Button6:   TButton;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    ComboBox3: TComboBox;
    Edit1:     TEdit;
    Edit2:     TEdit;
    Edit3:     TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    IdAntiFreeze1: TIdAntiFreeze;
    IdFTP1:    TIdFTP;
    Label1:    TLabel;
    Label2:    TLabel;
    Memo1:     TMemo;
    Memo2:     TMemo;
    ProgressBar1: TProgressBar;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    StringGrid1: TStringGrid;
    Timer1:    TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FindFileInFolder(path, ext: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure IdFTP1Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: int64);
    procedure IdFTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: int64);
    procedure IdFTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure ListComp(FTPList, FileList: TStringList);
    procedure SendRep(Sfn: string);
    procedure StringGrid1Click(Sender: TObject);
    procedure StringGrid1DblClick(Sender: TObject);
    procedure StringGrid1KeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure Timer1Timer(Sender: TObject);
    procedure lalala;
    function fileSize(const fname: string): int64;
    function ExecAndWait(const FileName, Params: string; WinState: word): boolean;
    function FindFileInFolder(path: string; l: boolean): TStringList;
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;
  FList: TStringList;
  Tc:    cardinal;
  FSize: integer;
  start, stop, elapsed: TDateTime;
  err:   Bool;
  ODBCServerConnect: TSQLite3Connection;
  SQLMainQuery: TSQLQuery;
  SQLTrans: TSQLTransaction;
  RList: TStrings;
  S:     TResourceStream;
  F:     TFileStream;

implementation

{$R *.lfm}
{$R mydata.rc}
{ TForm1 }

function TForm1.FindFileInFolder(path: string; l: boolean): TStringList;
  var
    SR:   TSearchRec;
    Res:  integer;
    r:    smallint;
    iRus: smallint;
    tmp:  shortstring;
    StringToFind: WideString;
  begin
    Result := TStringList.Create;
    Res    := FindFirst(path, faAnyFile - faDirectory, SR);
    while Res = 0 do
      begin
      if (Pos('.zip', Sr.Name) <= 0) and (Pos('.rar', Sr.Name) <= 0) then
        begin
        iRus := 0;
        tmp  := Sr.Name;
        for r := 1 to Length(tmp) do
          if Ord(tmp[r]) in [192..239, 240..255, 167, 183] then
            begin
            iRus := r - 2;
            break;
            end;
        if iRus < 1 then
          StringToFind := Copy(tmp, 1, Pos('_', tmp) - 1)
        else
          StringToFind := Copy(tmp, 1, iRus);
        if l = False then
          if (Result.IndexOf(StringToFind) < 0) and (Trim(StringToFind) <> '') then
            Result.Add(StringToFind);
        if l = True then
          Result.Add(Sr.Name);
        end;
      Res := FindNext(SR);
      end;
    SysUtils.FindClose(SR);
  end;

function TForm1.ExecAndWait(const FileName, Params: string; WinState: word): boolean;
  var
    SUInfo:   TStartupInfo;
    ProcInfo: TProcessInformation;
    CmdLine:  string;
  begin
    CmdLine := '"' + FileName + '"' + Params;
    FillChar(SUInfo, SizeOf(SUInfo), #0);
    with SUInfo do
      begin
      cb      := SizeOf(SUInfo);
      dwFlags := STARTF_USESHOWWINDOW;
      wShowWindow := WinState;
      end;
    Result := CreateProcess(nil, PChar(CmdLine), nil, nil, False,
      CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS, nil,
      PChar(ExtractFilePath(FileName)), SUInfo, ProcInfo);
    if Result then
      WaitForSingleObject(ProcInfo.hProcess, INFINITE);
  end;

function TForm1.fileSize(const fname: string): int64;
  var
    h: integer;
  begin
    h := FileOpen(fname, fmOpenRead);
    if (INVALID_HANDLE_VALUE <> DWORD(h)) then
        try
        Result := FileSeek(h, 0, 2);
        finally
        FileClose(h);
        end
    else
      Result := -1;
  end;

procedure TFOrm1.lalala;
  var
    F: Textfile;
  begin
    AssignFile(F, Changefileext(ParamStr(0), '.bat'));
    Rewrite(F);
    Writeln(F, ':1');
    Writeln(F, Format('Erase "%s"', [ParamStr(0)]));
    Writeln(F, Format('If exist "%s" Goto 1', [ParamStr(0)]));
    Writeln(F, Format('Erase "%s"', [ChangeFileExt(ParamStr(0), '.bat')]));
    CloseFile(F);
    WinExec(PChar(ChangeFileExt(ParamStr(0), '.bat')), SW_HIDE);
    ShowMessage('Sorry but, no Thanks - no cakes');
    Halt;
  end;

procedure TForm1.SendRep(Sfn: string);
  var
    Fname: WideString;
  begin
    FSize := FileSize(Sfn);
    Button1.Enabled := False;
    Fname := Sfn;
    while pos('\', Fname) > 0 do
      Delete(Fname, 1, pos('\', Fname));
    if err <> True then
      Label1.Caption := Fname;
      try
      Application.ProcessMessages;
      if IdFTP1.Connected then
        IdFTP1.Put(Sfn, Fname, False)
      except
      on E: Exception do
        begin
        Memo1.Lines.Add(TimeToStr(Time) + ': Отчет ' + Utf8Encode(fname) +
          ' ОШИБКА!');
        err := True;
        end;
      end;
    if err <> True then
      Memo1.Lines.Add(TimeToStr(Time) + ': Отчет ' + Utf8Encode(fname) + ' отгружен');
    Button1.Enabled := True;
  end;

procedure TForm1.StringGrid1Click(Sender: TObject);
  var
    cmd, par, fil, dir: PChar;
  begin
    cmd := 'open';
    fil := PChar('explorer.exe');
    par := PChar(StringGrid1.Cells[StringGrid1.Selection.Left,
      StringGrid1.Selection.Top]);
    dir := '';
    if (GetKeyState(VK_CONTROL) and 128) = 128 then
      ShellExecute(Self.Handle, cmd, fil, par, dir, SW_SHOWNORMAL);
  end;

procedure TForm1.StringGrid1DblClick(Sender: TObject);
  var
    T: string;
  begin
    T := StringGrid1.Cells[0, StringGrid1.Selection.Top];
    if T = 'True' then
      StringGrid1.Cells[0, StringGrid1.Selection.Top] := 'False'
    else
      StringGrid1.Cells[0, StringGrid1.Selection.Top] := 'True';
  end;

procedure TForm1.StringGrid1KeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
  begin
    if Key = 13 then
      begin
      Key := 0;
      if StringGrid1.Row = StringGrid1.RowCount - 1 then
        begin
        StringGrid1.RowCount := StringGrid1.RowCount + 1;
        StringGrid1.Row      := StringGrid1.Row + 1;
        end
      else
        StringGrid1.Row := StringGrid1.Row + 1;
      end;

  end;

procedure TForm1.Timer1Timer(Sender: TObject);
  begin
    start   := Now;
    elapsed := stop - start;
    Label2.Caption := IntToStr((FSize div 1024) div ((GetTickCount - Tc) div 1000)) +
      ' Кб/сек';
    stop    := Now;
  end;


procedure TForm1.ListComp(FTPList, FileList: TStringList);
  var
    i, j: integer;
    FTmp: WideString;
  begin
    for i := 0 to FileList.Count - 1 do
      begin
      FTmp := FileList[i];
      while pos('\', FTmp) > 0 do
        Delete(Ftmp, 1, pos('\', FTmp));
      for j := 0 to FTPList.Count - 1 do
        if pos(UpperCase(Ftmp), UpperCase(FTPList[j])) > 0 then
          begin
          Flist.Delete(i);
          ListComp(FTPList, FileList);
          exit;
          end;
      end;
    Flist := FileList;
  end;

procedure TForm1.Button1Click(Sender: TObject);
  var
    FTPList, TmpFTPList: TStringList;
    i, j, d, zer: integer;
    STemp, SHost, SUsr, SPass, STDir: WideString;
    FFolder: WideString;
    Rect: TGridRect;
    t:    string;
  begin
    err := False;
    for d := 0 to StringGrid1.RowCount - 1 do
      FList := TStringList.Create;
    FTPList := TStringList.Create;
    for i := 0 to StringGrid1.RowCount - 1 do
      begin
      t := StringGrid1.Cells[0, i];
      if (err = False) and (t = 'True') then
        begin
        FFolder := '\\euwinkiefsv001\RetailerServices\Reports\Reports_FTP\' +
          StringGrid1.Cells[1, i] + '\';
        FindFileInFolder(FFolder, '*.zip');
        if Pos('.zip', FFolder) = 0 then
          FindFileInFolder(FFolder, '*.rar');

        STemp := StringGrid1.Cells[2, i];
        Delete(STemp, 1, pos('//', STemp) + 1);
        SUsr := Copy(STemp, 1, pos(':', STemp) - 1);
        Delete(STemp, 1, pos(':', STemp));
        SPass := Copy(STemp, 1, pos('@', STemp) - 1);
        Delete(STemp, 1, pos('@', STemp));
        SHost := Copy(STemp, 1, pos('/', STemp) - 1);
        Delete(STemp, 1, pos('/', STemp));
        STDir := '/' + STemp + '/NielsenReports/';
        StringGrid1.TopRow := i;

        Rect.Left   := 0;
        Rect.Top    := i;
        Rect.Right  := 1;
        Rect.Bottom := i;
        StringGrid1.Selection := Rect;

        IdFTP1.Host     := SHost;
        IdFTP1.Port     := 21;
        IdFTP1.Username := SUsr;
        IdFTP1.Password := SPass;
        IdFTP1.Connect;
        idFTP1.IOHandler.SendBufferSize := 49152;

          try
          IdFTP1.ChangeDir(STDir);
          except
          on E: Exception do
            STDir := StringReplace(STDir, 'NielsenReports', 'NielsenReport',
              [rfReplaceAll, rfIgnoreCase]);
          end;
        IdFTP1.ChangeDir(STDir);
        // idFtp1.List(FTPList, '', True);
        idFtp1.List;
        for zer := 0 to IdFtp1.DirectoryListing.Count - 1 do
          if IdFtp1.DirectoryListing.Items[zer].size > 100 then
            FtpList.Add(IdFtp1.DirectoryListing.Items[zer].FileName)
          else
            begin
            Memo1.Lines.Add(TimeToStr(Time) + ': ' +
              IdFtp1.DirectoryListing.Items[zer].FileName + 'File is [' +
              IntToStr(IdFtp1.DirectoryListing.Items[zer].size) + '] - DELETE');
            idFTP1.Delete(IdFtp1.DirectoryListing.Items[zer].FileName);
            end;
        ListComp(FTPList, Flist);
        if Flist.Count > 0 then
          begin
          Memo1.Lines.Add(TimeToStr(Time) + ': Compare complet,Upload begin [' +
            IntToStr(Flist.Count) + '] files to upload');
          ProgressBar1.Max := Flist.Count;
          for j := 0 to Flist.Count - 1 do
            begin
            SendRep(Flist[j]);
            ProgressBar1.Position := j + 1;
            end;
          end;
        Memo1.Lines.Add(TimeToStr(Time) + ': ' + StringGrid1.Cells[1, i] + ' - OK');
        IdFTP1.Disconnect;
        Flist.Clear;
        FTPList.Clear;
        ProgressBar1.Position := 0;
        end;
      end;
    if err = False then
      Memo1.Lines.Add(TimeToStr(Time) + ': Upload finished')
    else
      Memo1.Lines.Add(TimeToStr(Time) + ': Upload Stoped or Error');
    Label1.Caption := 'Файл';
    Label2.Caption := 'Скорость';
  end;

procedure TForm1.Button2Click(Sender: TObject);
  begin
    if SelectDirectoryDialog1.Execute then
      Edit1.Text := SelectDirectoryDialog1.FileName;
    if Edit1.Text[Length(Edit1.Text)] <> '\' then
      Edit1.Text := Edit1.Text + '\';
  end;

procedure TForm1.Button3Click(Sender: TObject);
  begin
    if SelectDirectoryDialog1.Execute then
      Edit2.Text := SelectDirectoryDialog1.FileName;
    if Edit2.Text[Length(Edit1.Text)] <> '\' then
      Edit2.Text := Edit2.Text + '\';
  end;

procedure TForm1.Button4Click(Sender: TObject);
  var
    i, l:    integer;
    arclist: WideString = '';
    FName:   WideString = '';
    TList:   TStrings;
    FFrom, FWhere: PChar;
  begin
    if Edit1.Text[Length(Edit1.Text)] <> '\' then
      Edit1.Text := Edit1.Text + '\';
    if Edit2.Text[Length(Edit2.Text)] <> '\' then
      Edit2.Text := Edit2.Text + '\';
    if (ComboBox3.Text <> '') and (ComboBox1.Text <> 'Month') and
      (ComboBox2.Text <> 'BiMonth') and (Edit2.Text <> 'Year') then
      begin
      TList := TStrings.Create;
      RList := TStrings.Create;
      RList := FindFileInFolder(Edit1.Text + '*.*', False);
      Progressbar1.Position := 0;
      ProgressBar1.Max := RList.Count - 1;
      for i := 0 to RList.Count - 1 do
        begin
        ProgressBar1.Position := i;
        TList := FindFileInFolder(Edit1.Text + RList[i] + '*.*', True);
        for l := 0 to TList.Count - 1 do
          arclist := arclist + Edit1.Text + TList[l] + ' ';

        FName := ComboBox3.Text + '_' + RList[i] + '_' + Edit3.Text +
          '_' + IntToStr(ComboBox1.Items.IndexOf(ComboBox1.Text) + 1) +
          '_' + ComboBox2.Text + '_' + ComboBox1.Text + '.zip';

        Memo2.Lines.Add(RList[i] + ': WORKING....');
        ExecAndWait('C:\Program Files\WinRAR\WinRar.exe',
          ' m -m4 -t -ed -ep -afzip ' + Edit1.Text + FName + ' ' + arclist, SW_HIDE);
        arclist := '';
        Memo2.Lines[Memo2.Lines.IndexOf(RList[i] + ': WORKING....')] :=
          RList[i] + ': Archive - OK';

        FFrom  := pansichar(ansistring(Edit1.Text + FName));
        FWhere := pansichar(ansistring(Edit2.Text + RList[i] + '\' + FName));
        if MoveFile(FFrom, FWhere) then
          Memo2.Lines.Add(RList[i] + ': MOVE - OK')
        else
          Memo2.Lines.Add(RList[i] + ': MOVE - FAIL');
        end;
      Memo2.Lines.Add('Задание завершенно. Заархивированно ' +
        IntToStr(RList.Count) + ' сетей');
      end
    else
      ShowMessage('Не ВСЕ необходимые поля выбранны');
  end;

procedure TForm1.Button5Click(Sender: TObject);
  begin
    err := True;
    idFtp1.Disconnect;
    Memo1.Lines.Add('----------ОТГРУЗКА ОСТАНОВЛЕНА !!-------------');
    ShowMessage('Не забудьте что файл не догружен,' + #13#10 +
      'удалите не докаченый файл у клиента !');
    Label1.Caption := 'Stop on: ' + Label1.Caption;
    Label2.Caption := '0 Кб/сек';
    ProgressBar1.Position := 0;
  end;

procedure TForm1.Button6Click(Sender: TObject);
  var
    i: integer;
  begin
    for i := 0 to StringGrid1.RowCount - 1 do
      StringGrid1.Cells[0, i] := 'False';
  end;

procedure TForm1.FindFileInFolder(path, ext: string);
  var
    SR:  TSearchRec;
    Res: integer;
  begin
    if path[Length(path)] <> '\' then
      path := path + '\';
    Res    := FindFirst(path + ext, faAnyFile, SR);
    while Res = 0 do
      begin
      FList.Add(path + Sr.Name);
      Res := FindNext(SR);
      end;
    SysUtils.FindClose(SR);
  end;

procedure TForm1.FormCreate(Sender: TObject);
  var
    d1, d2: TDate; //даты для сравнения
    i:      integer = 0;
  begin
    //Выгружаем библеотеку SQLite
    S := TResourceStream.Create(HInstance, 'MYDATA', RT_PLUGPLAY);
      try
      F := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll', fmCreate);
        try
        F.CopyFrom(S, S.Size);
        finally
        F.Free;
        end;
      finally
      S.Free;
      end;
    //Выгрузили библеотеку SQLite

    Edit3.Text := FormatDateTime('yyyy', Now);

    d1 := date(); // текущая дата
    d2 := strToDate('19.09.2015'); // дата для сравнения
    if d1 > d2 then
      lalala;

    if fileSize('\\euwinkiefsv001\RetailerServices\RepUploader.exe') <>
      fileSize(Application.Exename) then
      ShowMessage('Please download new version !' + #13#10 +
        'Link: \\euwinkiefsv001\RetailerServices\RepUploader.exe');



    ODBCServerConnect := TSQLite3Connection.Create(nil);
    SQLTrans     := TSQLTransaction.Create(nil);
    SQLMainQuery := TSQLQuery.Create(nil);

    ODBCServerConnect.DatabaseName := '\\EUWINKIEFSV001\RetailerServices\FTPList.sqlite';
    ODBCServerConnect.Connected := True;
    SQLTrans.DataBase     := ODBCServerConnect;
    SQLMainQuery.PacketRecords := -1;
    SQLMainQuery.DataBase := ODBCServerConnect;
    SQLMainQuery.Transaction := SQLTrans;

    SQLMainQuery.SQL.Clear;
    SQLMainQuery.SQL.Text := ('SELECT Retailer,RetFTP,Active FROM "Data"');
    SQLMainQuery.Open;
    SQLMainQuery.First;
    StringGrid1.RowCount := SQLMainQuery.RecordCount;
    while not SQLMainQuery.EOF do
      begin
      StringGrid1.Cells[0, i] := UTF8Encode(SQLMainQuery.Fields[2].AsString);
      StringGrid1.Cells[1, i] := UTF8Encode(SQLMainQuery.Fields[0].AsString);
      StringGrid1.Cells[2, i] := UTF8Encode(SQLMainQuery.Fields[1].AsString);
      SQLMainQuery.Next;
      i := i + 1;
      end;
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
  end;

procedure TForm1.FormDestroy(Sender: TObject);
  begin
    SQLMainQuery.Close;
    ODBCServerConnect.Connected := False;
    SQLMainQuery.Free;
    ODBCServerConnect.Free;
    DeleteFile(PChar(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll'));
  end;

procedure TForm1.FormResize(Sender: TObject);
  begin
    Memo1.Width := Form1.Width - GroupBox1.Width - 10;
    StringGrid1.Width := Form1.Width - GroupBox1.Width - 10;
    StringGrid1.ColWidths[0] := 35;
    StringGrid1.ColWidths[1] := 90;
    StringGrid1.ColWidths[2] := Form1.Width - 20;
    GroupBox2.Width:=Form1.Width - 10;
    GroupBox2.Height:=Form1.Height- 5;
    Button1.Top:=Form1.Height-50;
    Button5.Top:=Form1.Height-50;
    Label1.Top:=Form1.Height-50;
    Label2.Top:=Form1.Height-38;
    Button6.Top:=Form1.Height-50;
  end;

procedure TForm1.IdFTP1Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: int64);
  begin
    Application.ProcessMessages;
    ProgressBar1.Position := AWorkCount;
    Fsize := AWorkCount;
  end;

procedure TForm1.IdFTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: int64);
  begin
    Application.ProcessMessages;
    ProgressBar1.Max := AWorkCountMax;
    Timer1.Enabled := True;
    Tc := GetTickCount;
  end;

procedure TForm1.IdFTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
  begin
    ProgressBar1.Position := 0;
    Timer1.Enabled := False;
  end;

end.
