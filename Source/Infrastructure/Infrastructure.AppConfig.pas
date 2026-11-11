unit Infrastructure.AppConfig;

/// <summary>
/// Application configuration loader.
/// Reads runtime settings from an INI file (app.ini) located either next to
/// the executable or in a "Config" subfolder.
/// Provides a single source of truth for Firebird connection parameters.
/// </summary>

interface

uses
  System.SysUtils;

type
  /// <summary>
  /// Firebird connection settings loaded from app.ini.
  /// </summary>
  TFirebirdConfig = record
    Enabled: Boolean;
    Server: string;
    Port: Integer;
    Database: string;
    User: string;
    Password: string;
  end;

  /// <summary>
  /// Static configuration reader for the application.
  /// </summary>
  TAppConfig = class
  private
    /// <summary>
    /// Resolves the path of the INI file. Looks first next to the EXE,
    /// then in Config\app.ini. Returns an empty string if nothing is found.
    /// </summary>
    class function ResolveIniPath: string; static;
  public
    /// <summary>
    /// Loads the Firebird configuration, applying defaults if the INI is missing.
    /// </summary>
    class function LoadFirebird: TFirebirdConfig; static;

    /// <summary>
    /// Returns True only if Firebird logging is enabled AND a database path is set.
    /// </summary>
    class function TryLoadFirebird(out AConfig: TFirebirdConfig): Boolean; static;
  end;

implementation

uses
  System.IOUtils,
  System.IniFiles;

class function TAppConfig.ResolveIniPath: string;
var
  Candidate: string;
begin
  // 1. Look for an INI file with the same name as the EXE (e.g. MyApp.ini)
  Candidate := ChangeFileExt(ParamStr(0), '.ini');
  if FileExists(Candidate) then
    Exit(Candidate);

  // 2. Fall back to Config\app.ini next to the EXE
  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Config\app.ini');
  if FileExists(Candidate) then
    Exit(Candidate);

  // 3. No configuration file found
  Result := '';
end;

class function TAppConfig.LoadFirebird: TFirebirdConfig;
var
  IniPath: string;
  Ini: TIniFile;
  DbPath: string;
begin
  // Sensible defaults for local development
  Result.Enabled := False;
  Result.Server := 'localhost';
  Result.Port := 3050;
  Result.Database := '';
  Result.User := 'SYSDBA';
  Result.Password := '';

  IniPath := ResolveIniPath;
  if IniPath = '' then
    Exit;

  Ini := TIniFile.Create(IniPath);
  try
    Result.Enabled := Ini.ReadBool('Firebird', 'Enabled', False);
    Result.Server := Ini.ReadString('Firebird', 'Server', 'localhost');
    Result.Port := Ini.ReadInteger('Firebird', 'Port', 3050);

    DbPath := Ini.ReadString('Firebird', 'Database', '');

    // Convert the relative database path into an absolute path based on the EXE location.
    // This allows the INI to contain paths like "..\..\Database\file.fdb".
    if (DbPath <> '') and (ExtractFileDrive(DbPath) = '') then
      DbPath := TPath.Combine(ExtractFilePath(ParamStr(0)), DbPath);

    Result.Database := DbPath;
    Result.User := Ini.ReadString('Firebird', 'User', 'SYSDBA');
    Result.Password := Ini.ReadString('Firebird', 'Password', '');
  finally
    Ini.Free;
  end;
end;

class function TAppConfig.TryLoadFirebird(out AConfig: TFirebirdConfig): Boolean;
begin
  AConfig := LoadFirebird;
  // Consider configuration valid only if logging is enabled and a database is set
  Result := AConfig.Enabled and (AConfig.Database <> '');
end;

end.
