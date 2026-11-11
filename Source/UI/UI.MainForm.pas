unit UI.MainForm;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids,
  Vcl.Skia, System.Skia, Vcl.Graphics, Winapi.Windows, Vcl.Dialogs,
  Domain.Types, Services.Simulator, Analysis.ThicknessEstimator, Data.FirebirdLogger,
  Physics.TMM, Data.CSV, Vcl.Imaging.pngimage, Winapi.Messages,
  System.IOUtils, Domain.Materials;

type
  // Helper class to expose protected members of TStringGrid (e.g., HideEditor)
  TCustomGridAccess = class(TStringGrid);

  TMainForm = class(TForm)
  private
    FModel: TOpticalModel;
    FMeasurements: TMeasurementArray;
    FTheoreticalData: TMeasurementArray;
    FLogger: TFirebirdLogger;

    FChart: TSkPaintBox;
    FResidualChart: TSkPaintBox;
    FDataGrid: TStringGrid;
    FStatusBar: TStatusBar;

    FLayersGrid: TStringGrid;
    FAngleEdit: TEdit;
    FEstimatedThicknessEdit: TEdit;

    FTypeface: ISkTypeface;
    FFont: ISkFont;

    // Chart zoom and pan state
    FZoom: Single;
    FPanX, FPanY: Single;
    FIsDragging: Boolean;
    FLastMousePos: TPoint;

    FMaterialCombo: TComboBox;

    procedure BuildInterface;
    procedure BuildSidebar;
    procedure BuildWorkspace;

    procedure UpdateDataGrid;
    procedure UpdateGridFromModel;
    procedure UpdateModelFromGrid;

    procedure HandleSimulateClick(Sender: TObject);
    procedure HandleEstimateClick(Sender: TObject);
    procedure HandleClearClick(Sender: TObject);
    procedure HandleAddLayerClick(Sender: TObject);
    procedure HandleRemoveLayerClick(Sender: TObject);
    procedure HandleImportCSVClick(Sender: TObject);
    procedure HandleExportCSVClick(Sender: TObject);
    procedure HandleExportPngClick(Sender: TObject);
    procedure HandleExportReportClick(Sender: TObject);
    procedure HandleGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure HandleMaterialComboChange(Sender: TObject);
    procedure HandleMaterialComboExit(Sender: TObject);
    procedure HandleGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HandleGridGetEditText(Sender: TObject; ACol, ARow: Integer; var Value: string);

    procedure RenderChart(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
    procedure RenderResiduals(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);

    procedure ChartMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ChartMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ChartMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  // Initialize Skia font for text rendering
  FTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Normal);
  FFont := ISkFont(TSkFont.Create(FTypeface, 12));
  FZoom := 1.0; FPanX := 0; FPanY := 0;

  FModel := TOpticalModel.Default;

  FLogger := TFirebirdLogger.Create;
  try
    FLogger.InitializeFromConfig;
  except
    on E: Exception do
      OutputDebugString(PChar('Logger init failed: ' + E.Message));
  end;

  BuildInterface;
  UpdateGridFromModel;

  // Select the first material cell to show the ComboBox immediately
  if FLayersGrid.RowCount > 1 then
  begin
    FLayersGrid.Col := 0;
    FLayersGrid.Row := 1;
    var DummyCanSelect: Boolean := True;
    HandleGridSelectCell(FLayersGrid, 0, 1, DummyCanSelect);
  end;
end;

destructor TMainForm.Destroy;
begin
  if Assigned(FLogger) then
  begin
    try
      FLogger.Free;
    except
      // Prevent logger errors from blocking application shutdown
    end;
  end;
  inherited;
end;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Ensure the window appears in the Windows taskbar
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
end;

procedure TMainForm.BuildInterface;
begin
  Caption := 'Ellipsometry Analyzer Pro';
  Width := 1400; Height := 900;
  Position := poScreenCenter;
  Color := $00F0F2F5; // Light gray background
  Font.Name := 'Segoe UI'; Font.Size := 10;

  BuildSidebar;
  BuildWorkspace;

  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
  FStatusBar.SimpleText := 'System Ready';
end;

procedure TMainForm.BuildSidebar;
var
  Sidebar: TPanel;
  Lbl: TLabel;
  Btn: TButton;
begin
  Sidebar := TPanel.Create(Self);
  Sidebar.Parent := Self;
  Sidebar.Align := alLeft;
  Sidebar.Width := 260;
  Sidebar.BevelOuter := bvNone;
  Sidebar.Color := $00202830; // Dark gray
  Sidebar.ParentBackground := False;

  // Title
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Sidebar;
  Lbl.SetBounds(20, 20, 200, 30);
  Lbl.Caption := 'ELLIPSOMETRY';
  Lbl.Font.Name := 'Segoe UI Semibold';
  Lbl.Font.Size := 14;
  Lbl.Font.Color := clWhite;

  // Layers section label
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Sidebar;
  Lbl.SetBounds(20, 60, 200, 20);
  Lbl.Caption := 'Optical Layers:';
  Lbl.Font.Color := $00A0AAB5;

  // 1. Layers Grid
  FLayersGrid := TStringGrid.Create(Self);
  FLayersGrid.Parent := Sidebar;
  FLayersGrid.SetBounds(20, 80, 220, 120);
  FLayersGrid.FixedRows := 1;
  FLayersGrid.FixedCols := 0;
  FLayersGrid.ColCount := 4;
  FLayersGrid.RowCount := 2;
  FLayersGrid.ColWidths[0] := 70; // Material
  FLayersGrid.ColWidths[1] := 50; // Thickness
  FLayersGrid.ColWidths[2] := 45; // N
  FLayersGrid.ColWidths[3] := 45; // K
  FLayersGrid.Cells[0,0] := 'Material';
  FLayersGrid.Cells[1,0] := 'Thick';
  FLayersGrid.Cells[2,0] := 'N';
  FLayersGrid.Cells[3,0] := 'K';
  FLayersGrid.Options := FLayersGrid.Options + [goEditing];
  FLayersGrid.OnSelectCell := HandleGridSelectCell;
  FLayersGrid.OnMouseDown := HandleGridMouseDown;
  FLayersGrid.OnGetEditText := HandleGridGetEditText;


  // 2. Floating ComboBox for material selection
  FMaterialCombo := TComboBox.Create(Self);
  FMaterialCombo.Parent := Sidebar;
  FMaterialCombo.Visible := False;
  FMaterialCombo.Style := csDropDownList;
  FMaterialCombo.OnChange := HandleMaterialComboChange;
  FMaterialCombo.OnExit := HandleMaterialComboExit;
  TMaterialLibrary.PopulateComboBox(FMaterialCombo.Items);

  // Add/Remove Layer Buttons
  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(20, 210, 105, 25);
  Btn.Caption := '+ Layer'; Btn.OnClick := HandleAddLayerClick;

  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(135, 210, 105, 25);
  Btn.Caption := '- Layer'; Btn.OnClick := HandleRemoveLayerClick;

  // Incidence Angle
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Sidebar;
  Lbl.SetBounds(20, 250, 200, 20);
  Lbl.Caption := 'Angle (deg)';
  Lbl.Font.Color := $00A0AAB5;

  FAngleEdit := TEdit.Create(Self);
  FAngleEdit.Parent := Sidebar;
  FAngleEdit.SetBounds(20, 270, 220, 30);
  FAngleEdit.Text := '70';

  // Action Buttons
  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(20, 320, 220, 35);
  Btn.Caption := 'Simulate Data'; Btn.OnClick := HandleSimulateClick;

  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(20, 365, 220, 35);
  Btn.Caption := 'Run Fit (Estimate)'; Btn.OnClick := HandleEstimateClick;

  // Import/Export CSV
  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(20, 420, 105, 30);
  Btn.Caption := 'Import CSV...'; Btn.OnClick := HandleImportCSVClick;

  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(135, 420, 105, 30);
  Btn.Caption := 'Export CSV...'; Btn.OnClick := HandleExportCSVClick;

  // Fitted Thickness
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Sidebar;
  Lbl.SetBounds(20, 470, 200, 20);
  Lbl.Caption := 'Fitted Thickness (Layer 1):';
  Lbl.Font.Color := $00A0AAB5;

  FEstimatedThicknessEdit := TEdit.Create(Self);
  FEstimatedThicknessEdit.Parent := Sidebar;
  FEstimatedThicknessEdit.SetBounds(20, 490, 220, 30);
  FEstimatedThicknessEdit.ReadOnly := True;

  // Export PNG / Report
  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(20, 535, 105, 30);
  Btn.Caption := 'Export PNG'; Btn.OnClick := HandleExportPngClick;

  Btn := TButton.Create(Self);
  Btn.Parent := Sidebar; Btn.SetBounds(135, 535, 105, 30);
  Btn.Caption := 'Export Report'; Btn.OnClick := HandleExportReportClick;

  if (FLayersGrid.RowCount > 1) and (Trim(FLayersGrid.Cells[0, 1]) = '') and (FMaterialCombo.Items.Count > 0) then
  begin
    // Set the default material for the first data row immediately upon creation
    FLayersGrid.Cells[0, 1] := FMaterialCombo.Items[0];
  end;
    // 3. Explicitly reset the combo box item index to 0 so it doesn't default to the 5th item
  if FMaterialCombo.Items.Count > 0 then
  begin
    FMaterialCombo.ItemIndex := 0;
  end;
end;

procedure TMainForm.BuildWorkspace;
var
  MainPanel, TopPanel, MidPanel, BottomPanel: TPanel;
begin
  MainPanel := TPanel.Create(Self);
  MainPanel.Parent := Self;
  MainPanel.Align := alClient;
  MainPanel.BevelOuter := bvNone;
  MainPanel.Padding.SetBounds(20, 20, 20, 20);

  // 1. Main Chart (Top)
  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := MainPanel;
  TopPanel.Align := alTop;
  TopPanel.Height := 320;
  TopPanel.BevelOuter := bvNone;
  TopPanel.Color := clWhite;

  FChart := TSkPaintBox.Create(Self);
  FChart.Parent := TopPanel;
  FChart.Align := alClient;
  FChart.OnDraw := RenderChart;
  FChart.OnMouseDown := ChartMouseDown;
  FChart.OnMouseMove := ChartMouseMove;
  FChart.OnMouseUp := ChartMouseUp;

  // 2. Residual Chart (Middle)
  MidPanel := TPanel.Create(Self);
  MidPanel.Parent := MainPanel;
  MidPanel.Align := alTop;
  MidPanel.Height := 180;
  MidPanel.BevelOuter := bvNone;
  MidPanel.Color := clWhite;
  MidPanel.Margins.SetBounds(0, 10, 0, 0);

  FResidualChart := TSkPaintBox.Create(Self);
  FResidualChart.Parent := MidPanel;
  FResidualChart.Align := alClient;
  FResidualChart.OnDraw := RenderResiduals;

  // 3. Data Grid (Bottom)
  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := MainPanel;
  BottomPanel.Align := alClient;
  BottomPanel.BevelOuter := bvNone;
  BottomPanel.Color := clWhite;
  BottomPanel.Margins.SetBounds(0, 10, 0, 0);

  FDataGrid := TStringGrid.Create(Self);
  FDataGrid.Parent := BottomPanel;
  FDataGrid.Align := alClient;
  FDataGrid.FixedRows := 1;
  FDataGrid.FixedCols := 0;
  FDataGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect];
  FDataGrid.ColWidths[0] := 150;
  FDataGrid.ColWidths[1] := 150;
  FDataGrid.ColWidths[2] := 150;
  FDataGrid.Cells[0, 0] := 'Wavelength (nm)';
  FDataGrid.Cells[1, 0] := 'Psi (deg)';
  FDataGrid.Cells[2, 0] := 'Delta (deg)';


end;

procedure TMainForm.UpdateDataGrid;
var I: Integer;
begin
  FDataGrid.RowCount := Length(FMeasurements) + 1;
  for I := 0 to High(FMeasurements) do
  begin
    FDataGrid.Cells[0, I+1] := FormatFloat('0.0', FMeasurements[I].WavelengthNm);
    FDataGrid.Cells[1, I+1] := FormatFloat('0.00', FMeasurements[I].PsiDeg);
    FDataGrid.Cells[2, I+1] := FormatFloat('0.00', FMeasurements[I].DeltaDeg);
  end;
end;

procedure TMainForm.UpdateGridFromModel;
var I: Integer;
begin
  FLayersGrid.RowCount := Length(FModel.Layers) + 1;
  for I := 0 to High(FModel.Layers) do
  begin
    FLayersGrid.Cells[0, I+1] := FModel.Layers[I].MaterialName;
    FLayersGrid.Cells[1, I+1] := FormatFloat('0.0', FModel.Layers[I].ThicknessNm);
    FLayersGrid.Cells[2, I+1] := FormatFloat('0.00', FModel.Layers[I].N);
    FLayersGrid.Cells[3, I+1] := FormatFloat('0.00', FModel.Layers[I].K);
  end;
end;

procedure TMainForm.UpdateModelFromGrid;
var I: Integer; T, N, K: Double;
begin
  SetLength(FModel.Layers, FLayersGrid.RowCount - 1);
  for I := 0 to FLayersGrid.RowCount - 2 do
  begin
    if not TryStrToFloat(FLayersGrid.Cells[1, I+1], T) then T := 0;
    if not TryStrToFloat(FLayersGrid.Cells[2, I+1], N) then N := 1;
    if not TryStrToFloat(FLayersGrid.Cells[3, I+1], K) then K := 0;

    FModel.Layers[I].MaterialName := FLayersGrid.Cells[0, I+1];
    FModel.Layers[I].ThicknessNm := T;
    FModel.Layers[I].N := N;
    FModel.Layers[I].K := K;
  end;
end;

procedure TMainForm.WMMouseWheel(var Message: TWMMouseWheel);
var
  MousePos: TPoint;
begin
  // Convert global mouse position to form client coordinates
  MousePos := Point(Message.XPos, Message.YPos);
  MousePos := ScreenToClient(MousePos);

  // Check if the mouse is over the main chart
  if PtInRect(FChart.ClientRect, FChart.ScreenToClient(ClientToScreen(MousePos))) then
  begin
    // Apply zoom based on wheel direction
    if Message.WheelDelta > 0 then
      FZoom := FZoom * 1.1   // Scroll up = Zoom In
    else
      FZoom := FZoom / 1.1;  // Scroll down = Zoom Out

    // Clamp zoom limits
    if FZoom < 0.5 then FZoom := 0.5;
    if FZoom > 10.0 then FZoom := 10.0;

    FChart.Redraw;

    // Mark message as handled
    Message.Result := 1;
  end
  else
    inherited;
end;

procedure TMainForm.HandleAddLayerClick(Sender: TObject);
begin
  UpdateModelFromGrid;
  SetLength(FModel.Layers, Length(FModel.Layers) + 1);
  FModel.Layers[High(FModel.Layers)].MaterialName := 'TiO2';
  FModel.Layers[High(FModel.Layers)].ThicknessNm := 50;
  FModel.Layers[High(FModel.Layers)].N := 2.40;
  FModel.Layers[High(FModel.Layers)].K := 0;
  UpdateGridFromModel;
end;

procedure TMainForm.HandleRemoveLayerClick(Sender: TObject);
begin
  UpdateModelFromGrid;
  if Length(FModel.Layers) > 1 then
  begin
    SetLength(FModel.Layers, Length(FModel.Layers) - 1);
    UpdateGridFromModel;
  end;
end;

procedure TMainForm.HandleSimulateClick(Sender: TObject);
var Angle: Double;
begin
  UpdateModelFromGrid;

  if not TryStrToFloat(FAngleEdit.Text, Angle) or (Angle <= 0) or (Angle >= 90) then
  begin
    ShowMessage('Invalid angle. Must be between 0 and 90 degrees.');
    Exit;
  end;
  FModel.IncidenceAngleDeg := Angle;

  // Generate synthetic data with slight noise for realistic residuals
  FMeasurements := TMeasurementSimulator.Generate(FModel, 400, 800, 161, 0.5);
  FTheoreticalData := nil;

  UpdateDataGrid;
  FChart.Redraw;
  FResidualChart.Redraw;
  FStatusBar.SimpleText := Format('Simulation complete. %d samples.', [Length(FMeasurements)]);
end;

procedure TMainForm.HandleEstimateClick(Sender: TObject);
var Est: Double; BestModel: TOpticalModel;
begin
  if Length(FMeasurements) = 0 then
  begin
    ShowMessage('Please simulate or import data first.');
    Exit;
  end;

  UpdateModelFromGrid;

  if Length(FModel.Layers) = 0 then
  begin
    ShowMessage('No layers defined in the model.');
    Exit;
  end;

  try
    Est := TThicknessEstimator.EstimateSingle(FMeasurements, FModel, 10, 300, 300);

    FLayersGrid.Cells[1, 1] := FormatFloat('0.0', Est);
    UpdateModelFromGrid;

    FEstimatedThicknessEdit.Text := FormatFloat('0.00', Est);

    BestModel := FModel;
    BestModel.Layers[0].ThicknessNm := Est;
    FTheoreticalData := TMeasurementSimulator.Generate(BestModel, 400, 800, Length(FMeasurements), 0);

    FChart.Redraw;
    FResidualChart.Redraw;
    FStatusBar.SimpleText := Format('Fit successful: %.2f nm', [Est]);
  except
    on E: Exception do
      FStatusBar.SimpleText := 'Fit error: ' + E.Message;
  end;
end;

procedure TMainForm.HandleClearClick(Sender: TObject);
begin
  FMeasurements := nil;
  FTheoreticalData := nil;
  FDataGrid.RowCount := 1;
  FChart.Redraw;
  FResidualChart.Redraw;
  FStatusBar.SimpleText := 'Cleared.';
end;

procedure TMainForm.HandleExportPngClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Surface: ISkSurface;
  Image: ISkImage;
begin
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'PNG Image (*.png)|*.png';
    Dlg.DefaultExt := 'png';
    if not Dlg.Execute then Exit;

    // Create raster surface matching chart dimensions
    Surface := TSkSurface.MakeRaster(Trunc(FChart.Width), Trunc(FChart.Height));
    Surface.Canvas.Clear(TAlphaColorRec.White);

    // Draw chart onto the surface
    RenderChart(Self, Surface.Canvas, TRectF.Create(0, 0, FChart.Width, FChart.Height), 1.0);

    // Save to file
    Image := Surface.MakeImageSnapshot;
    Image.EncodeToFile(Dlg.FileName, TSkEncodedImageFormat.PNG, 100);

    FStatusBar.SimpleText := 'Chart exported as PNG.';
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.HandleExportReportClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  Lines: TStringList;
  I: Integer;
begin
  if Length(FMeasurements) = 0 then
  begin
    ShowMessage('No data to report.');
    Exit;
  end;

  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Export Ellipsometry Report';
    Dlg.Filter := 'Text Report (*.txt)|*.txt|All Files (*.*)|*.*';
    Dlg.DefaultExt := 'txt';
    Dlg.FileName := 'Ellipsometry_Report.txt';

    if not Dlg.Execute then Exit;

    Lines := TStringList.Create;
    try
      Lines.Add('--- ELLIPSOMETRY ANALYSIS REPORT ---');
      Lines.Add('Date: ' + DateTimeToStr(Now));
      Lines.Add('Angle of Incidence: ' + FAngleEdit.Text + ' deg');
      Lines.Add(StringOfChar('-', 36));
      Lines.Add('');

      Lines.Add('OPTICAL MODEL PARAMETERS:');
      Lines.Add(Format('  Substrate: N = %.3f, K = %.3f', [FModel.SubstrateN, FModel.SubstrateK]));

      for I := 0 to High(FModel.Layers) do
      begin
        Lines.Add(Format('  Layer %d: %s', [I + 1, FModel.Layers[I].MaterialName]));
        Lines.Add(Format('    * Thickness:  %.2f nm', [FModel.Layers[I].ThicknessNm]));
        Lines.Add(Format('    * Constants:  N = %.3f | K = %.3f', [FModel.Layers[I].N, FModel.Layers[I].K]));
      end;

      Lines.Add('');
      Lines.Add('FIT QUALITY & STATISTICS:');
      Lines.Add('  Estimated Thickness (Layer 1): ' + FEstimatedThicknessEdit.Text + ' nm');
      Lines.Add('  Total Data Points (Psi/Delta): ' + IntToStr(Length(FMeasurements)));

      Lines.Add('');
      Lines.Add(StringOfChar('-', 36));
      Lines.Add('Status: Analysis completed successfully');

      Lines.SaveToFile(Dlg.FileName);
      FStatusBar.SimpleText := 'Report successfully exported to ' + ExtractFileName(Dlg.FileName);
    finally
      Lines.Free;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.HandleGridGetEditText(Sender: TObject; ACol, ARow: Integer; var Value: string);
begin
  // Block the internal text editor for the Material column
  // so that the ComboBox can take over.
  if (ACol = 0) and (ARow > 0) then
    Value := '';
end;

procedure TMainForm.HandleGridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ACol, ARow: Integer;
  R: TRect;
  MatchedIndex: Integer;
begin
  // Determine which cell was clicked based on mouse coordinates
  FLayersGrid.MouseToCell(X, Y, ACol, ARow);

  // Check if the click is on the Material column (Column 0) and a valid data row (> 0)
  if (ACol = 0) and (ARow > 0) then
  begin
    // Force immediate hiding of the grid's native internal text editor
    TCustomGridAccess(FLayersGrid).HideEditor;

    // If the clicked cell is completely empty, assign the first item as default
    if (Trim(FLayersGrid.Cells[ACol, ARow]) = '') and (FMaterialCombo.Items.Count > 0) then
    begin
      FLayersGrid.Cells[ACol, ARow] := FMaterialCombo.Items[0];
    end;

    // Calculate the cell rectangle and offset it relative to the sidebar container
    R := FLayersGrid.CellRect(ACol, ARow);
    R.Offset(FLayersGrid.Left, FLayersGrid.Top);

    // Position and size the combo box directly over the grid cell
    FMaterialCombo.SetBounds(R.Left, R.Top, R.Width, R.Height);

    // Safely match the current cell text with the combo box items
    MatchedIndex := FMaterialCombo.Items.IndexOf(FLayersGrid.Cells[ACol, ARow]);
    if MatchedIndex >= 0 then
      FMaterialCombo.ItemIndex := MatchedIndex
    else if FMaterialCombo.Items.Count > 0 then
    begin
      // Fallback to the first item if no match exists
      FMaterialCombo.ItemIndex := 0;
      FLayersGrid.Cells[ACol, ARow] := FMaterialCombo.Items[0];
    end;

    // Make the combo box visible and bring it to the front of the UI stack
    FMaterialCombo.Visible := True;
    FMaterialCombo.BringToFront();

    // Safely request keyboard focus if the window handle is allocated and ready
    if FMaterialCombo.HandleAllocated and FMaterialCombo.CanFocus then
      FMaterialCombo.SetFocus;

    // Update the active grid cell coordinates
    FLayersGrid.Col := ACol;
    FLayersGrid.Row := ARow;
  end;
end;

procedure TMainForm.HandleGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  R: TRect;
begin
  CanSelect := True;

  // If the form is not shown yet or the grid doesn't have focus, hide the ComboBox
  if not Showing or not FLayersGrid.Focused then
  begin
    if Assigned(FMaterialCombo) then
      FMaterialCombo.Visible := False;
    Exit;
  end;

  if (ACol = 0) and (ARow > 0) then
  begin
    // Hide the internal editor
    TCustomGridAccess(FLayersGrid).HideEditor;

    // Get cell rectangle and translate it relative to the sidebar
    R := FLayersGrid.CellRect(ACol, ARow);
    R.Offset(FLayersGrid.Left, FLayersGrid.Top);

    // Position the ComboBox
    FMaterialCombo.SetBounds(R.Left, R.Top, R.Width, R.Height);
    FMaterialCombo.Text := FLayersGrid.Cells[ACol, ARow];

    FMaterialCombo.Visible := True;
    FMaterialCombo.BringToFront();

    if FMaterialCombo.HandleAllocated and FMaterialCombo.CanFocus then
      FMaterialCombo.SetFocus;
  end
  else
  begin
    FMaterialCombo.Visible := False;
  end;
end;

procedure TMainForm.HandleMaterialComboChange(Sender: TObject);
var
  Mat: TMaterialInfo;
  Row: Integer;
begin
  if not FMaterialCombo.Visible then Exit;

  Row := FLayersGrid.Row;
  if Row > 0 then
  begin
    FLayersGrid.Cells[0, Row] := FMaterialCombo.Text;

    if FMaterialCombo.Text <> 'Custom' then
    begin
      Mat := TMaterialLibrary.GetMaterial(FMaterialCombo.Text);
      FLayersGrid.Cells[2, Row] := FormatFloat('0.000', Mat.N);
      FLayersGrid.Cells[3, Row] := FormatFloat('0.000', Mat.K);
    end;

    UpdateModelFromGrid;
  end;
end;

procedure TMainForm.HandleMaterialComboExit(Sender: TObject);
begin
  // Hide the ComboBox when it loses focus (user clicked elsewhere)
  FMaterialCombo.Visible := False;
end;

procedure TMainForm.HandleImportCSVClick(Sender: TObject);
var Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
    if Dlg.Execute then
    begin
      try
        FMeasurements := TCSVService.ImportMeasurements(Dlg.FileName);
        FTheoreticalData := nil;
        UpdateDataGrid;
        FChart.Redraw;
        FResidualChart.Redraw;
        FStatusBar.SimpleText := Format('Imported %d points.', [Length(FMeasurements)]);
      except
        on E: Exception do
          ShowMessage('Import error: ' + E.Message);
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.HandleExportCSVClick(Sender: TObject);
var Dlg: TSaveDialog;
begin
  if Length(FMeasurements) = 0 then
  begin
    ShowMessage('No data to export.');
    Exit;
  end;

  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'CSV Files (*.csv)|*.csv';
    Dlg.DefaultExt := 'csv';
    if Dlg.Execute then
    begin
      TCSVService.ExportMeasurements(Dlg.FileName, FMeasurements);
      FStatusBar.SimpleText := 'Data exported to ' + Dlg.FileName;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.RenderChart(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  P: ISkPaint;
  Path: ISkPathBuilder;
  I: Integer;
  X, Y, L, T, W, H: Single;
begin
  ACanvas.Clear(TAlphaColorRec.White);

  // Apply zoom and pan transformations
  ACanvas.Save;
  ACanvas.Translate(FPanX, FPanY);
  ACanvas.Scale(FZoom, FZoom);

  P := TSkPaint.Create;
  P.AntiAlias := True;

  L := 60; T := 30; W := ADest.Width - 100; H := ADest.Height - 60;
  if (W < 20) or (H < 20) then Exit;

  // Draw Grid
  P.Style := TSkPaintStyle.Stroke;
  P.Color := $FFE0E0E0;
  P.StrokeWidth := 1;
  for I := 0 to 5 do
  begin
    Y := T + I * H / 5;
    ACanvas.DrawLine(PointF(L, Y), PointF(L + W, Y), P);
  end;

  // Draw Axes
  P.Color := $FF000000;
  P.StrokeWidth := 2;
  ACanvas.DrawLine(PointF(L, T), PointF(L, T + H), P);
  ACanvas.DrawLine(PointF(L, T + H), PointF(L + W, T + H), P);

  // Draw Labels
  P.Style := TSkPaintStyle.Fill;
  P.Color := $FF000000;
  for I := 0 to 4 do
  begin
    Y := T + H - (I * 20) / 90 * H;
    ACanvas.DrawSimpleText(IntToStr(I * 20), 10, Y + 5, FFont, P);
    X := L + (I * 100) / 400 * W;
    ACanvas.DrawSimpleText(IntToStr(400 + I * 100), X - 10, T + H + 20, FFont, P);
  end;

  if Length(FMeasurements) = 0 then Exit;

  // Draw Measured Lines (Solid)
  P.Style := TSkPaintStyle.Stroke;
  P.StrokeWidth := 2;
  P.PathEffect := nil;

  P.Color := $FF007BFF; // Blue
  Path := TSkPathBuilder.Create;
  for I := 0 to High(FMeasurements) do
  begin
    X := L + (FMeasurements[I].WavelengthNm - 400) / 400 * W;
    Y := T + H - FMeasurements[I].PsiDeg / 90 * H;
    if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
  end;
  ACanvas.DrawPath(Path.Snapshot, P);

  P.Color := $FFFF8C00; // Orange
  Path := TSkPathBuilder.Create;
  for I := 0 to High(FMeasurements) do
  begin
    X := L + (FMeasurements[I].WavelengthNm - 400) / 400 * W;
    Y := T + H - FMeasurements[I].DeltaDeg / 360 * H;
    if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
  end;
  ACanvas.DrawPath(Path.Snapshot, P);

  // Draw Theoretical Lines (Dashed)
  if Length(FTheoreticalData) > 0 then
  begin
    P.PathEffect := TSkPathEffect.MakeDash([8, 6], 0);
    P.StrokeWidth := 2;

    // Theoretical Psi (Dark Blue)
    P.Color := $FF00008B;
    Path := TSkPathBuilder.Create;
    for I := 0 to High(FTheoreticalData) do
    begin
      X := L + (FTheoreticalData[I].WavelengthNm - 400) / 400 * W;
      Y := T + H - FTheoreticalData[I].PsiDeg / 90 * H;
      if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
    end;
    ACanvas.DrawPath(Path.Snapshot, P);

    // Theoretical Delta (Dark Brown)
    P.Color := $FF8B4500;
    Path := TSkPathBuilder.Create;
    for I := 0 to High(FTheoreticalData) do
    begin
      X := L + (FTheoreticalData[I].WavelengthNm - 400) / 400 * W;
      Y := T + H - FTheoreticalData[I].DeltaDeg / 360 * H;
      if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
    end;
    ACanvas.DrawPath(Path.Snapshot, P);

    P.PathEffect := nil;
  end;

  // Draw Legend
  P.Style := TSkPaintStyle.Fill;
  P.Color := $FF000000;
  ACanvas.DrawSimpleText('— Measured', L + 20, T + 15, FFont, P);
  ACanvas.DrawSimpleText('-- Model', L + 120, T + 15, FFont, P);
  ACanvas.Restore;
end;

procedure TMainForm.ChartMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FIsDragging := True;
    FLastMousePos := Point(X, Y);
  end;
end;

procedure TMainForm.ChartMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FIsDragging then
  begin
    FPanX := FPanX + (X - FLastMousePos.X);
    FPanY := FPanY + (Y - FLastMousePos.Y);
    FLastMousePos := Point(X, Y);
    FChart.Redraw;
  end;
end;

procedure TMainForm.ChartMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    FIsDragging := False;
end;

procedure TMainForm.RenderResiduals(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  P: ISkPaint;
  Path: ISkPathBuilder;
  I: Integer;
  X, Y, L, T, W, H, CenterY: Single;
  PsiRes, DeltaRes: Double;
begin
  ACanvas.Clear($FFF8F9FA);

  P := TSkPaint.Create;
  P.AntiAlias := True;
  P.Style := TSkPaintStyle.Stroke;
  P.StrokeWidth := 1.5;

  L := 60; T := 20; W := ADest.Width - 100; H := ADest.Height - 60;
  if (W < 20) or (H < 20) then Exit;

  CenterY := T + H / 2;

  // 1. Vertical Grid (every 100 nm)
  P.Color := $FFE0E0E0;
  P.StrokeWidth := 1;
  for I := 0 to 4 do
  begin
    X := L + (I * 100) / 400 * W;
    ACanvas.DrawLine(PointF(X, T), PointF(X, T + H), P);
  end;

  // 2. Zero Line (Center)
  P.Color := $FFAAAAAA;
  ACanvas.DrawLine(PointF(L, CenterY), PointF(L + W, CenterY), P);

  // 3. Main Axes
  P.Color := $FF000000;
  P.StrokeWidth := 2;
  ACanvas.DrawLine(PointF(L, T), PointF(L, T + H), P);
  ACanvas.DrawLine(PointF(L, T + H), PointF(L + W, T + H), P);

  // 4. Y-Axis Labels (+10, 0, -10)
  P.Style := TSkPaintStyle.Fill;
  P.Color := $FF000000;
  ACanvas.DrawSimpleText('+10', 15, T + 5, FFont, P);
  ACanvas.DrawSimpleText('0', 25, CenterY + 5, FFont, P);
  ACanvas.DrawSimpleText('-10', 15, T + H, FFont, P);

  // 5. X-Axis Labels (400, 500, 600, 700, 800)
  for I := 0 to 4 do
  begin
    X := L + (I * 100) / 400 * W;
    ACanvas.DrawSimpleText(IntToStr(400 + I * 100), X - 10, T + H + 25, FFont, P);
  end;

  // 6. Title
  ACanvas.DrawSimpleText('Residuals (Measured - Model)', L + 10, T + 10, FFont, P);

  if (Length(FMeasurements) = 0) or (Length(FTheoreticalData) = 0) then Exit;
  if Length(FMeasurements) <> Length(FTheoreticalData) then Exit;

  // 7. Psi Residuals (Blue)
  P.Style := TSkPaintStyle.Stroke;
  P.Color := $FF007BFF;
  P.StrokeWidth := 1.5;
  Path := TSkPathBuilder.Create;
  for I := 0 to High(FMeasurements) do
  begin
    PsiRes := FMeasurements[I].PsiDeg - FTheoreticalData[I].PsiDeg;
    X := L + (FMeasurements[I].WavelengthNm - 400) / 400 * W;
    Y := CenterY - (PsiRes / 10) * (H / 2); // Scale +/- 10 degrees
    if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
  end;
  ACanvas.DrawPath(Path.Snapshot, P);

  // 8. Delta Residuals (Orange)
  P.Color := $FFFF8C00;
  Path := TSkPathBuilder.Create;
  for I := 0 to High(FMeasurements) do
  begin
    DeltaRes := FMeasurements[I].DeltaDeg - FTheoreticalData[I].DeltaDeg;
    while DeltaRes > 180 do DeltaRes := DeltaRes - 360;
    while DeltaRes < -180 do DeltaRes := DeltaRes + 360;

    X := L + (FMeasurements[I].WavelengthNm - 400) / 400 * W;
    Y := CenterY - (DeltaRes / 10) * (H / 2);
    if I = 0 then Path.MoveTo(X, Y) else Path.LineTo(X, Y);
  end;
  ACanvas.DrawPath(Path.Snapshot, P);
end;

end.
