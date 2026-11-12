unit Data.FirebirdLogger;

/// <summary>
/// Firebird logging service using FireDAC.
/// Writes structured log entries to the APP_LOG table.
/// Falls back to a local text file (Logs\fallback.log) if the database
/// connection is unavailable, so the application never loses diagnostics.
/// </summary>

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  Infrastructure.AppConfig;

type
  /// <summary>
  /// Firebird logger with local fallback.
  /// </summary>
  TFirebirdLogger = class
  private
    FConnection: TFDConnection;
    FConnected: Boolean;
    FFallbackFile: string;

    /// <summary>
    /// Writes a line to the local fallback log file (creates folder if needed).
    /// </summary>
    procedure WriteFallback(const ALine: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Applies connection parameters (does not connect yet).
    /// </summary>
    procedure Configure(const AConfig: TFirebirdConfig);

    /// <summary>
    /// Opens the Firebird connection. Never raises: on failure sets FConnected=False
    /// and writes the error to the fallback file.
    /// </summary>
    procedure Connect;

    /// <summary>
    /// Loads app.ini and, if enabled, configures and connects the logger.
    /// </summary>
    procedure InitializeFromConfig;

    /// <summary>
    /// Writes a log entry to Firebird. If not connected, writes to fallback.
    /// </summary>
    procedure Log(const ALevel, ACategory, AMessage: string);

    /// <summary>
    /// True if the Firebird connection is currently open.
    /// </summary>
    property Connected: Boolean read FConnected;
  end;

implementation

uses
  System.IOUtils,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef;

constructor TFirebirdLogger.Create;
begin
  inherited;
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  FFallbackFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Logs\fallback.log');
end;

destructor TFirebirdLogger.Destroy;
begin
  FConnection.Free;
  inherited;
end;

procedure TFirebirdLogger.Configure(const AConfig: TFirebirdConfig);
begin
  FConnection.Connected := False;
  FConnection.Params.Clear;
  FConnection.DriverName := 'FB';

  // Hardcoded Local protocol for the current demo.
  // In production, expose Server/Port/Protocol via INI or environment variables.
  FConnection.Params.Values['Database'] := AConfig.Database;
  FConnection.Params.Values['User_Name'] := AConfig.User;
  FConnection.Params.Values['Password'] := AConfig.Password;
  FConnection.Params.Values['CharacterSet'] := 'UTF8';

  // Path to the native Firebird client (adjust if your installation differs)
  FConnection.Params.Values['VendorLib'] := AConfig.Path_to_native_Firebird_client;

  FConnection.Params.Values['Protocol'] := 'Local';
end;

procedure TFirebirdLogger.Connect;
begin
  try
    FConnection.Connected := True;
    FConnected := True;
    WriteFallback('INFO Firebird connected.');
  except
    on E: Exception do
    begin
      FConnected := False;
      WriteFallback('ERROR Firebird connection failed: ' + E.Message);
    end;
  end;
end;

procedure TFirebirdLogger.InitializeFromConfig;
var
  Config: TFirebirdConfig;
begin
  if not TAppConfig.TryLoadFirebird(Config) then
  begin
    WriteFallback('INFO Firebird logging disabled or not configured.');
    Exit;
  end;
  Configure(Config);
  Connect;
end;

procedure TFirebirdLogger.WriteFallback(const ALine: string);
begin
  ForceDirectories(ExtractFileDir(FFallbackFile));
  TFile.AppendAllText(
    FFallbackFile,
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + ALine + sLineBreak,
    TEncoding.UTF8);
end;

procedure TFirebirdLogger.Log(const ALevel, ACategory, AMessage: string);
var
  Query: TFDQuery;
begin
  // If not connected, we can only write to the fallback file
  if not FConnected then
  begin
    WriteFallback(ALevel + ' [' + ACategory + '] ' + AMessage);
    Exit;
  end;

  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'insert into APP_LOG (LOG_TIME, LOG_LEVEL, CATEGORY, MESSAGE_TEXT) ' +
        'values (:P_TIME, :P_LEVEL, :P_CATEGORY, :P_MESSAGE)';

      Query.ParamByName('P_TIME').AsDateTime := Now;
      Query.ParamByName('P_LEVEL').AsString := Copy(ALevel, 1, 16);
      Query.ParamByName('P_CATEGORY').AsString := Copy(ACategory, 1, 80);
      Query.ParamByName('P_MESSAGE').AsString := Copy(AMessage, 1, 2000);
      Query.ExecSQL;
    except
      on E: Exception do
      begin
        // If the insert fails, drop the connection and log to fallback
        FConnected := False;
        WriteFallback('ERROR log insert failed: ' + E.Message);
        WriteFallback(ALevel + ' [' + ACategory + '] ' + AMessage);
      end;
    end;
  finally
    Query.Free;
  end;
end;

end.
