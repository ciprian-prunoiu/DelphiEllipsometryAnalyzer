program DelphiEllipsometryAnalyzer;

uses
  Vcl.Forms,
  Vcl.Skia,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef,
  FireDAC.UI.Intf,
  FireDAC.VCLUI.Wait,
  UI.MainForm in 'Source\UI\UI.MainForm.pas',
  Domain.Types in 'Source\Domain\Domain.Types.pas',
  Physics.Complex in 'Source\Physics\Physics.Complex.pas',
  Services.Simulator in 'Source\Services\Services.Simulator.pas',
  Analysis.ThicknessEstimator in 'Source\Analysis\Analysis.ThicknessEstimator.pas',
  Infrastructure.AppConfig in 'Source\Infrastructure\Infrastructure.AppConfig.pas',
  Data.FirebirdLogger in 'Source\Data\Data.FirebirdLogger.pas',
  Data.MeasurementCsv in 'Source\Data\Data.MeasurementCsv.pas',
  Physics.TMM in 'Source\Physics\Physics.TMM.pas',
  Data.CSV in 'Source\Data\Data.CSV.pas',
  Domain.Materials in 'Source\Domain\Domain.Materials.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Delphi Ellipsometry Analyzer';
  Application.CreateForm(TMainForm, MainForm);
  //MainForm:=TMainForm.CreateNew(Application);
  Application.Run;
end.
