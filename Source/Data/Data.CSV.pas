unit Data.CSV;

/// <summary>
/// Simple CSV import/export service for ellipsometric measurements.
/// Reads and writes files in the format: Wavelength,Psi,Delta.
/// Handles local decimal separators (comma vs dot) transparently.
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Domain.Types;

type
  /// <summary>
  /// Static service for reading and writing measurement CSVs.
  /// </summary>
  TCSVService = class
  public
    /// <summary>
    /// Exports measurements to a CSV file with a header row.
    /// </summary>
    class procedure ExportMeasurements(const AFileName: string; const AData: TMeasurementArray);

    /// <summary>
    /// Imports measurements from a CSV file, skipping an optional header.
    /// Supports both comma and semicolon delimiters.
    /// </summary>
    class function ImportMeasurements(const AFileName: string): TMeasurementArray;
  end;

implementation

uses
  System.IOUtils, System.Math;

class procedure TCSVService.ExportMeasurements(const AFileName: string; const AData: TMeasurementArray);
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    // Header row
    Lines.Add('Wavelength(nm),Psi(deg),Delta(deg)');

    // Data rows (fixed precision for reproducibility)
    for I := 0 to High(AData) do
    begin
      Lines.Add(Format('%.2f,%.4f,%.4f',
        [AData[I].WavelengthNm, AData[I].PsiDeg, AData[I].DeltaDeg]));
    end;

    Lines.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

class function TCSVService.ImportMeasurements(const AFileName: string): TMeasurementArray;
var
  Lines: TStringList;
  I: Integer;
  Parts: TArray<string>;
  Line: string;
  W, P, D: Double;
  TempList: TList<TMeasurement>;
  M: TMeasurement;
begin
  if not FileExists(AFileName) then
    raise Exception.Create('File not found: ' + AFileName);

  TempList := TList<TMeasurement>.Create;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName, TEncoding.UTF8);

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;

      // Skip the header line if present
      if (I = 0) and (Line.ToLower.Contains('wavelength') or Line.ToLower.Contains('psi')) then
        Continue;

      // Normalize semicolons to commas (some instruments use European CSV)
      Line := Line.Replace(';', ',');
      Parts := Line.Split([',']);

      if Length(Parts) >= 3 then
      begin
        // Replace decimal comma with dot for localized systems (RO/DE/FR)
        if TryStrToFloat(Parts[0].Replace(',', '.'), W) and
           TryStrToFloat(Parts[1].Replace(',', '.'), P) and
           TryStrToFloat(Parts[2].Replace(',', '.'), D) then
        begin
          M.WavelengthNm := W;
          M.PsiDeg := P;
          M.DeltaDeg := D;
          TempList.Add(M);
        end;
      end;
    end;

    Result := TempList.ToArray;
  finally
    Lines.Free;
    TempList.Free;
  end;
end;

end.
