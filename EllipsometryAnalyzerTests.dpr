program EllipsometryAnalyzerTests;

/// <summary>
/// DUnitX test runner for the Ellipsometry Analyzer.
/// Supports two execution modes:
///   - TestInsight (when {$DEFINE TESTINSIGHT} is active)
///   - Console runner (default), with optional NUnit XML output for CI.
/// </summary>

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,

  // Logger backends depend on the execution mode
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}

  DUnitX.TestFramework,

  // Test fixtures
  Tests.Physics in 'Source\Tests\Tests.Physics.pas';

{ Keep this comment so the IDE does not strip the conditional when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger: ITestLogger;
{$ENDIF}

begin
{$IFDEF TESTINSIGHT}
  // Run through the TestInsight IDE plugin
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Validate command-line options (exits on invalid input)
    TDUnitX.CheckCommandLine;

    // Create the test runner
    runner := TDUnitX.CreateRunner;
    runner.UseRTTI := True;            // Auto-discover fixtures via RTTI
    runner.FailsOnNoAsserts := False;  // Allow tests without assertions

    // Console logger (respects quiet mode if requested on the command line)
    if TDUnitX.Options.ConsoleMode <> TDUnitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(
        TDUnitX.Options.ConsoleMode = TDUnitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;

    // NUnit-compatible XML logger (useful for CI pipelines)
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    // Execute the test suite
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    // Pause before exiting when not running under CI
    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;

  System.Readln;
{$ENDIF}
end.
