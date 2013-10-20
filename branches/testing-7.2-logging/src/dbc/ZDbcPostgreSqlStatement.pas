{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         PostgreSQL Database Connectivity Classes        }
{                                                         }
{        Originally written by Sergey Seroukhov           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcPostgreSqlStatement;

interface

{$I ZDbc.inc}

uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, Types,
  ZSysUtils, ZDbcIntfs, ZDbcStatement, ZDbcLogging, ZPlainPostgreSqlDriver,
  ZCompatibility, ZVariant, ZDbcGenericResolver, ZDbcCachedResultSet,
  ZDbcPostgreSql;

type

  {** Defines a PostgreSQL specific statement. }
  IZPostgreSQLStatement = interface(IZStatement)
    ['{E4FAFD96-97CC-4247-8ECC-6E0A168FAFE6}']

    function IsOidAsBlob: Boolean;
  end;

  {** Implements Generic PostgreSQL Statement. }
  TZPostgreSQLStatement = class(TZAbstractStatement, IZPostgreSQLStatement)
  private
    FPlainDriver: IZPostgreSQLPlainDriver;
    FOidAsBlob: Boolean;
  protected
    function CreateResultSet(const SQL: string;
      QueryHandle: PZPostgreSQLResult): IZResultSet;
    function GetConnectionHandle():PZPostgreSQLConnect;
  public
    constructor Create(PlainDriver: IZPostgreSQLPlainDriver;
      Connection: IZConnection; Info: TStrings);
    destructor Destroy; override;

    function ExecuteQuery(const SQL: RawByteString): IZResultSet; override;
    function ExecuteUpdate(const SQL: RawByteString): Integer; override;
    function Execute(const SQL: RawByteString): Boolean; override;

    function IsOidAsBlob: Boolean;
  end;

  {$IFDEF ZEOS_TEST_ONLY}
  {** Implements Emulated Prepared SQL Statement. }
  TZPostgreSQLEmulatedPreparedStatement = class(TZEmulatedPreparedStatement)
  private
    FPlainDriver: IZPostgreSQLPlainDriver;
    Foidasblob: Boolean;
  protected
    function CreateExecStatement: IZStatement; override;
    function PrepareAnsiSQLParam(ParamIndex: Integer): RawByteString; override;
    function GetConnectionHandle: PZPostgreSQLConnect;
  public
    constructor Create(PlainDriver: IZPostgreSQLPlainDriver;
      Connection: IZConnection; const SQL: string; Info: TStrings);
  end;
  {$ENDIF}

  TZPostgreSQLPreparedStatement = class(TZAbstractPreparedStatement)
  private
    FRawPlanName: RawByteString;
    FPostgreSQLConnection: IZPostgreSQLConnection;
    FPlainDriver: IZPostgreSQLPlainDriver;
    QueryHandle: PZPostgreSQLResult;
    Foidasblob: Boolean;
    FConnectionHandle: PZPostgreSQLConnect;
    Findeterminate_datatype: Boolean;
    function CreateResultSet(QueryHandle: PZPostgreSQLResult): IZResultSet;
  protected
    procedure SetPlanNames; virtual; abstract;
  public
    constructor Create(PlainDriver: IZPostgreSQLPlainDriver;
      Connection: IZPostgreSQLConnection; const SQL: string; Info: TStrings);
    destructor Destroy; override;
  end;

  {** EgonHugeist: Implements Prepared SQL Statement with AnsiString usage }
  TZPostgreSQLClassicPreparedStatement = class(TZPostgreSQLPreparedStatement)
  private
    FExecSQL: RawByteString;
    function GetAnsiSQLQuery: RawByteString;
  protected
    procedure SetPlanNames; override;
    function PrepareAnsiSQLParam(ParamIndex: Integer; Escaped: Boolean): RawByteString;
    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
  public
    procedure Prepare; override;

    function ExecuteQuery(const SQL: RawByteString): IZResultSet; override;
    function ExecuteUpdate(const SQL: RawByteString): Integer; override;
    function Execute(const SQL: RawByteString): Boolean; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;
  end;

  {** EgonHugeist: Implements Prepared SQL Statement based on Protocol3
    ServerVersion 7.4Up and ClientVersion 8.0Up. with C++API usage}
  TZPostgreSQLCAPIPreparedStatement = class(TZPostgreSQLPreparedStatement)
  private
    FPQparamValues: TPQparamValues;
    FPQparamLengths: TPQparamLengths;
    FPQparamFormats: TPQparamFormats;
    function ExecuteInternal(const SQL: RawByteString; const LogSQL: String;
      const LoggingCategory: TZLoggingCategory): PZPostgreSQLResult;
  protected
    procedure SetPlanNames; override;
    procedure SetASQL(const Value: RawByteString); override;
    procedure SetWSQL(const Value: ZWideString); override;
    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
    function PrepareAnsiSQLQuery: RawByteString;

  public
    procedure Prepare; override;
    procedure Unprepare; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;
  end;

  {** Implements callable Postgresql Statement. }
  TZPostgreSQLCallableStatement = class(TZAbstractCallableStatement)
  private
    Foidasblob: Boolean;
    FPlainDriver: IZPostgreSQLPlainDriver;
    function GetProcedureSql: string;
    function FillParams(const ASql: String): RawByteString;
    function PrepareAnsiSQLParam(ParamIndex: Integer): RawByteString;
  protected
    function GetConnectionHandle:PZPostgreSQLConnect;
    function GetPlainDriver:IZPostgreSQLPlainDriver;
    function CreateResultSet(const SQL: string;
      QueryHandle: PZPostgreSQLResult): IZResultSet;
    procedure FetchOutParams(ResultSet: IZResultSet);
    procedure TrimInParameters; override;
  public
    constructor Create(Connection: IZConnection; const SQL: string; Info: TStrings);

    function ExecuteQuery(const SQL: RawByteString): IZResultSet; override;
    function ExecuteUpdate(const SQL: RawByteString): Integer; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
  end;

  {** Implements a specialized cached resolver for PostgreSQL. }
  TZPostgreSQLCachedResolver = class(TZGenericCachedResolver, IZCachedResolver)
  protected
    function CheckKeyColumn(ColumnIndex: Integer): Boolean; override;
  end;

implementation

uses
  {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings, {$ENDIF}
  ZFastCode, ZMessages, ZDbcPostgreSqlResultSet, ZDbcPostgreSqlUtils,
  ZTokenizer, ZEncoding, ZDbcUtils;

{ TZPostgreSQLStatement }

{**
  Constructs this object and assignes the main properties.
  @param PlainDriver a PostgreSQL plain driver.
  @param Connection a database connection object.
  @param Info a statement parameters.
  @param Handle a connection handle pointer.
}
constructor TZPostgreSQLStatement.Create(PlainDriver: IZPostgreSQLPlainDriver;
  Connection: IZConnection; Info: TStrings);
begin
  inherited Create(Connection, Info);
  FPlainDriver := PlainDriver;
  ResultSetType := rtScrollInsensitive;

  { Processes connection properties. }
  FOidAsBlob := StrToBoolEx(Self.Info.Values['oidasblob'])
    or (Connection as IZPostgreSQLConnection).IsOidAsBlob;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZPostgreSQLStatement.Destroy;
begin
  inherited Destroy;
end;

{**
  Checks is oid should be treated as Large Object.
  @return <code>True</code> if oid should represent a Large Object.
}
function TZPostgreSQLStatement.IsOidAsBlob: Boolean;
begin
  Result := FOidAsBlob;
end;

{**
  Creates a result set based on the current settings.
  @return a created result set object.
}
function TZPostgreSQLStatement.CreateResultSet(const SQL: string;
  QueryHandle: PZPostgreSQLResult): IZResultSet;
var
  NativeResultSet: TZPostgreSQLResultSet;
  CachedResultSet: TZCachedResultSet;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  ConnectionHandle := GetConnectionHandle();
  NativeResultSet := TZPostgreSQLResultSet.Create(FPlainDriver, Self, SQL,
  ConnectionHandle, QueryHandle, CachedLob, ChunkSize);

  NativeResultSet.SetConcurrency(rcReadOnly);
  if GetResultSetConcurrency = rcUpdatable then
  begin
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, SQL, nil, ConSettings);
    CachedResultSet.SetConcurrency(rcUpdatable);
    CachedResultSet.SetResolver(TZPostgreSQLCachedResolver.Create(
      Self,  NativeResultSet.GetMetadata));
    Result := CachedResultSet;
  end
  else
    Result := NativeResultSet;
end;

{**
  Executes an SQL statement that returns a single <code>ResultSet</code> object.
  @param sql typically this is a static SQL <code>SELECT</code> statement
  @return a <code>ResultSet</code> object that contains the data produced by the
    given query; never <code>null</code>
}
function TZPostgreSQLStatement.ExecuteQuery(const SQL: RawByteString): IZResultSet;
var
  QueryHandle: PZPostgreSQLResult;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  Result := nil;
  ConnectionHandle := GetConnectionHandle();
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := FPlainDriver.ExecuteQuery(ConnectionHandle, PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, ConnectionHandle, lcExecute,
    SSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, LogSQL);
  if QueryHandle <> nil then
    Result := CreateResultSet(LogSQL, QueryHandle)
  else
    Result := nil;
end;

{**
  Executes an SQL <code>INSERT</code>, <code>UPDATE</code> or
  <code>DELETE</code> statement. In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @param sql an SQL <code>INSERT</code>, <code>UPDATE</code> or
    <code>DELETE</code> statement or an SQL statement that returns nothing
  @return either the row count for <code>INSERT</code>, <code>UPDATE</code>
    or <code>DELETE</code> statements, or 0 for SQL statements that return nothing
}
function TZPostgreSQLStatement.ExecuteUpdate(const SQL: RawByteString): Integer;
var
  QueryHandle: PZPostgreSQLResult;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  Result := -1;
  ConnectionHandle := GetConnectionHandle();

  ASQL := SQL; //Prepares SQL if needed
  QueryHandle := FPlainDriver.ExecuteQuery(ConnectionHandle, PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, ConnectionHandle, lcExecute,
    LogSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, LogSQL);

  if QueryHandle <> nil then
  begin
    Result := RawToIntDef(FPlainDriver.GetCommandTuples(QueryHandle), 0);
    FPlainDriver.Clear(QueryHandle);
  end;

  { Autocommit statement. }
  if Connection.GetAutoCommit then
    Connection.Commit;
end;

{**
  Executes an SQL statement that may return multiple results.
  Under some (uncommon) situations a single SQL statement may return
  multiple result sets and/or update counts.  Normally you can ignore
  this unless you are (1) executing a stored procedure that you know may
  return multiple results or (2) you are dynamically executing an
  unknown SQL string.  The  methods <code>execute</code>,
  <code>getMoreResults</code>, <code>getResultSet</code>,
  and <code>getUpdateCount</code> let you navigate through multiple results.

  The <code>execute</code> method executes an SQL statement and indicates the
  form of the first result.  You can then use the methods
  <code>getResultSet</code> or <code>getUpdateCount</code>
  to retrieve the result, and <code>getMoreResults</code> to
  move to any subsequent result(s).

  @param sql any SQL statement
  @return <code>true</code> if the next result is a <code>ResultSet</code> object;
  <code>false</code> if it is an update count or there are no more results
}
function TZPostgreSQLStatement.Execute(const SQL: RawByteString): Boolean;
var
  QueryHandle: PZPostgreSQLResult;
  ResultStatus: TZPostgreSQLExecStatusType;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  ASQL := SQL;
  ConnectionHandle := GetConnectionHandle();
  QueryHandle := FPlainDriver.ExecuteQuery(ConnectionHandle, PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, ConnectionHandle, lcExecute,
    LogSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, LogSQL);

  { Process queries with result sets }
  ResultStatus := FPlainDriver.GetResultStatus(QueryHandle);
  case ResultStatus of
    PGRES_TUPLES_OK:
      begin
        Result := True;
        LastResultSet := CreateResultSet(LogSQL, QueryHandle);
      end;
    PGRES_COMMAND_OK:
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
    else
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
  end;

  { Autocommit statement. }
  if not Result and Connection.GetAutoCommit then
    Connection.Commit;
end;

{**
  Provides connection handle from the associated IConnection
}
function TZPostgreSQLStatement.GetConnectionHandle():PZPostgreSQLConnect;
begin
  if Self.Connection = nil then
    Result := nil
  else
    Result := (Connection as IZPostgreSQLConnection).GetConnectionHandle;
end;

{$IFDEF ZEOS_TEST_ONLY}
{ TZPostgreSQLEmulatedPreparedStatement }

{**
  Constructs this object and assignes the main properties.
  @param PlainDriver a PostgreSQL plain driver.
  @param Connection a database connection object.
  @param Info a statement parameters.
  @param Handle a connection handle pointer.
}
constructor TZPostgreSQLEmulatedPreparedStatement.Create(
  PlainDriver: IZPostgreSQLPlainDriver; Connection: IZConnection;
  const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  FPlainDriver := PlainDriver;
  ResultSetType := rtScrollInsensitive;
  Foidasblob := StrToBoolDef(Self.Info.Values['oidasblob'], False) or
    (Connection as IZPostgreSQLConnection).IsOidAsBlob;
end;

{**
  Creates a temporary statement which executes queries.
  @return a created statement object.
}
function TZPostgreSQLEmulatedPreparedStatement.CreateExecStatement: IZStatement;
begin
  Result := TZPostgreSQLStatement.Create(FPlainDriver, Connection, Info);
end;

{**
  Prepares an SQL parameter for the query.
  @param ParameterIndex the first parameter is 1, the second is 2, ...
  @return a string representation of the parameter.
}
function TZPostgreSQLEmulatedPreparedStatement.PrepareAnsiSQLParam(
  ParamIndex: Integer): RawByteString;
begin
  if InParamCount <= ParamIndex then
    raise EZSQLException.Create(SInvalidInputParameterCount);

  Result := PGPrepareAnsiSQLParam(InParamValues[ParamIndex], ClientVarManager,
    (Connection as IZPostgreSQLConnection), FPlainDriver, ChunkSize,
    InParamTypes[ParamIndex], Foidasblob, True, False, ConSettings);
end;

{**
  Provides connection handle from the associated IConnection
}
function TZPostgreSQLEmulatedPreparedStatement.GetConnectionHandle:PZPostgreSQLConnect;
begin
  if Self.Connection = nil then
    Result := nil
  else
    Result := (self.Connection as IZPostgreSQLConnection).GetConnectionHandle;
end;
{$ENDIF}

{ TZPostgreSQLPreparedStatement }

{**
  Creates a result set based on the current settings.
  @param QueryHandle the Postgres query handle
  @return a created result set object.
}
constructor TZPostgreSQLPreparedStatement.Create(PlainDriver: IZPostgreSQLPlainDriver;
  Connection: IZPostgreSQLConnection; const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  Foidasblob := StrToBoolDef(Self.Info.Values['oidasblob'], False) or
    (Connection as IZPostgreSQLConnection).IsOidAsBlob;
  FPostgreSQLConnection := Connection;
  FPlainDriver := PlainDriver;
  ResultSetType := rtScrollInsensitive;
  FConnectionHandle := Connection.GetConnectionHandle;
  Findeterminate_datatype := False;
  SetPlanNames;
end;

destructor TZPostgreSQLPreparedStatement.Destroy;
begin
  inherited Destroy;
end;

function TZPostgreSQLPreparedStatement.CreateResultSet(QueryHandle: Pointer): IZResultSet;
var
  NativeResultSet: TZPostgreSQLResultSet;
  CachedResultSet: TZCachedResultSet;
begin
  NativeResultSet := TZPostgreSQLResultSet.Create(FPlainDriver, Self, Self.SQL,
  FConnectionHandle, QueryHandle, CachedLob, ChunkSize);

  NativeResultSet.SetConcurrency(rcReadOnly);
  if GetResultSetConcurrency = rcUpdatable then
  begin
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, Self.SQL, nil,
      ConSettings);
    CachedResultSet.SetConcurrency(rcUpdatable);
    CachedResultSet.SetResolver(TZPostgreSQLCachedResolver.Create(
      Self,  NativeResultSet.GetMetadata));
    Result := CachedResultSet;
  end
  else
    Result := NativeResultSet;
end;

{ TZPostgreSQLClassicPreparedStatement }

function TZPostgreSQLClassicPreparedStatement.GetAnsiSQLQuery;
var
  I: Integer;
  ParamIndex: Integer;
begin
  ParamIndex := 0;
  Result := '';
  for I := 0 to High(CachedQueryRaw) do
    if IsParamIndex[I] then
    begin
      Result := Result + PrepareAnsiSQLParam(ParamIndex, True);
      Inc(ParamIndex);
    end
    else
      Result := Result + CachedQueryRaw[i];
end;

procedure TZPostgreSQLClassicPreparedStatement.SetPlanNames;
begin
  FRawPlanName := '"'+IntToRaw(Int64(Hash(ASQL)+Cardinal(FStatementId)+NativeUInt(FConnectionHandle)))+'"';
end;

function TZPostgreSQLClassicPreparedStatement.PrepareAnsiSQLParam(ParamIndex: Integer;
  Escaped: Boolean): RawByteString;
begin
  if InParamCount <= ParamIndex then
    raise EZSQLException.Create(SInvalidInputParameterCount);

  Result := PGPrepareAnsiSQLParam(InParamValues[ParamIndex], ClientVarManager,
    (Connection as IZPostgreSQLConnection), FPlainDriver, ChunkSize,
    InParamTypes[ParamIndex], Foidasblob, Escaped, True, ConSettings);
end;

procedure TZPostgreSQLClassicPreparedStatement.PrepareInParameters;
var
  I, N: Integer;
  TempSQL: RawByteString;
  QueryHandle: PZPostgreSQLResult;
begin
  if Length(CachedQueryRaw) > 1 then //params found
  begin
    TempSQL := 'PREPARE '+FRawPlanName+' AS ';
    N := 0;
    for I := 0 to High(CachedQueryRaw) do
      if IsParamIndex[i] then
      begin
        Inc(N);
        TempSQL := TempSQL + '$' + IntToRaw(N);
      end
      else
        TempSQL := TempSQL + CachedQueryRaw[i];
    {$IFNDEF UNICODE}
    if ConSettings^.AutoEncode then
       TempSQL := GetConnection.GetDriver.GetTokenizer.GetEscapeString(TempSQL);
    {$ENDIF}
  end
  else Exit;

  ASQL := TempSQL;
  QueryHandle := FPlainDriver.ExecuteQuery(FConnectionHandle,
    PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, FConnectionHandle, lcPrepStmt,
    SSQL, QueryHandle);
  FPlainDriver.Clear(QueryHandle);
end;

procedure TZPostgreSQLClassicPreparedStatement.BindInParameters;
var
  I: Integer;
begin
  if InParamCount > 0 then
    if Prepared then
    begin
      FExecSQL := 'EXECUTE '+FRawPlanName+'(';
      for i := 0 to InParamCount -1 do
        if I = 0 then
          FExecSQL := FExecSQL+PrepareAnsiSQLParam(i, False)
        else
          FExecSQL := FExecSQL+','+PrepareAnsiSQLParam(i, False);
      FExecSQL := FExecSQL+');';
    end
    else
      FExecSQL := GetAnsiSQLQuery
  else
    FExecSQL := ASQL;
  {$IFNDEF UNICODE}
  if GetConnection.AutoEncodeStrings then
     FExecSQL := GetConnection.GetDriver.GetTokenizer.GetEscapeString(FExecSQL);
  {$ENDIF}
end;

procedure TZPostgreSQLClassicPreparedStatement.UnPrepareInParameters;
begin
  if Prepared and Assigned(FPostgreSQLConnection.GetConnectionHandle) then
  begin
    ASQL := 'DEALLOCATE '+FRawPlanName+';';
    Execute(ASQL);
  end;
end;

procedure TZPostgreSQLClassicPreparedStatement.Prepare;
begin
  { EgonHugeist: assume automated Prepare after third execution. That's the way
    the JDBC Drivers go too... }
  if (not Prepared ) and ( InParamCount > 0 ) and ( ExecCount > 2 ) then
    inherited Prepare;
  BindInParameters;
end;

{**
  Executes an SQL statement that returns a single <code>ResultSet</code> object.
  @param sql typically this is a static SQL <code>SELECT</code> statement
  @return a <code>ResultSet</code> object that contains the data produced by the
    given query; never <code>null</code>
}
function TZPostgreSQLClassicPreparedStatement.ExecuteQuery(const SQL: RawByteString): IZResultSet;
begin
  Result := nil;
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := FPlainDriver.ExecuteQuery(FConnectionHandle, PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver,
    FConnectionHandle, lcExecute, SSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, Self.SSQL);
  if QueryHandle <> nil then
    Result := CreateResultSet(QueryHandle)
  else
    Result := nil;
end;

{**
  Executes an SQL <code>INSERT</code>, <code>UPDATE</code> or
  <code>DELETE</code> statement. In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @param sql an SQL <code>INSERT</code>, <code>UPDATE</code> or
    <code>DELETE</code> statement or an SQL statement that returns nothing
  @return either the row count for <code>INSERT</code>, <code>UPDATE</code>
    or <code>DELETE</code> statements, or 0 for SQL statements that return nothing
}
function TZPostgreSQLClassicPreparedStatement.ExecuteUpdate(const SQL: RawByteString): Integer;
var
  QueryHandle: PZPostgreSQLResult;
begin
  Result := -1;
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := FPlainDriver.ExecuteQuery(FConnectionHandle, PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, FConnectionHandle, lcExecute,
    SSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, SSQL);

  if QueryHandle <> nil then
  begin
    Result := RawToIntDef(FPlainDriver.GetCommandTuples(QueryHandle), 0);
    FPlainDriver.Clear(QueryHandle);
  end;

  { Autocommit statement. }
  if Connection.GetAutoCommit then
    Connection.Commit;
end;

{**
  Executes an SQL statement that may return multiple results.
  Under some (uncommon) situations a single SQL statement may return
  multiple result sets and/or update counts.  Normally you can ignore
  this unless you are (1) executing a stored procedure that you know may
  return multiple results or (2) you are dynamically executing an
  unknown SQL string.  The  methods <code>execute</code>,
  <code>getMoreResults</code>, <code>getResultSet</code>,
  and <code>getUpdateCount</code> let you navigate through multiple results.

  The <code>execute</code> method executes an SQL statement and indicates the
  form of the first result.  You can then use the methods
  <code>getResultSet</code> or <code>getUpdateCount</code>
  to retrieve the result, and <code>getMoreResults</code> to
  move to any subsequent result(s).

  @param sql any SQL statement
  @return <code>true</code> if the next result is a <code>ResultSet</code> object;
  <code>false</code> if it is an update count or there are no more results
}
function TZPostgreSQLClassicPreparedStatement.Execute(const SQL: RawByteString): Boolean;
var
  QueryHandle: PZPostgreSQLResult;
  ResultStatus: TZPostgreSQLExecStatusType;
begin
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := FPlainDriver.ExecuteQuery(FConnectionHandle,
    PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, FPlainDriver, FConnectionHandle, lcExecute,
    SSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, FPlainDriver.GetProtocol, SSQL);

  { Process queries with result sets }
  ResultStatus := FPlainDriver.GetResultStatus(QueryHandle);
  case ResultStatus of
    PGRES_TUPLES_OK:
      begin
        Result := True;
        LastResultSet := CreateResultSet(QueryHandle);
      end;
    PGRES_COMMAND_OK:
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
    else
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
  end;

  { Autocommit statement. }
  if not Result and Connection.GetAutoCommit then
    Connection.Commit;
end;

{**
  Executes the SQL query in this <code>PreparedStatement</code> object
  and returns the result set generated by the query.

  @return a <code>ResultSet</code> object that contains the data produced by the
    query; never <code>null</code>
}
function TZPostgreSQLClassicPreparedStatement.ExecuteQueryPrepared: IZResultSet;
begin
  Prepare;
  Result := ExecuteQuery(FExecSQL);
  inherited ExecuteQueryPrepared;
end;

{**
  Executes the SQL INSERT, UPDATE or DELETE statement
  in this <code>PreparedStatement</code> object.
  In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @return either the row count for INSERT, UPDATE or DELETE statements;
  or 0 for SQL statements that return nothing
}
function TZPostgreSQLClassicPreparedStatement.ExecuteUpdatePrepared: Integer;
begin
  Prepare;
  Result := ExecuteUpdate(FExecSQL);
  inherited ExecuteUpdatePrepared;
end;

{**
  Executes any kind of SQL statement.
  Some prepared statements return multiple results; the <code>execute</code>
  method handles these complex statements as well as the simpler
  form of statements handled by the methods <code>executeQuery</code>
  and <code>executeUpdate</code>.
  @see Statement#execute
}
function TZPostgreSQLClassicPreparedStatement.ExecutePrepared: Boolean;
begin
  Prepare;
  Result := Execute(FExecSQL);
  inherited ExecutePrepared;
end;

{ TZPostgreSQLCAPIPreparedStatement }

function TZPostgreSQLCAPIPreparedStatement.ExecuteInternal(const SQL: RawByteString;
  const LogSQL: String; const LoggingCategory: TZLoggingCategory): PZPostgreSQLResult;
begin
  case LoggingCategory of
    lcPrepStmt:
      begin
        Result := FPlainDriver.Prepare(FConnectionHandle, PAnsiChar(FRawPlanName),
          PAnsiChar(SQL), InParamCount, nil);
        Findeterminate_datatype := (CheckPostgreSQLError(Connection, FPlainDriver,
          FConnectionHandle, LoggingCategory, LogSQL, Result) = '42P18');
        if not Findeterminate_datatype then
          FPostgreSQLConnection.RegisterPreparedStmtName({$IFDEF UNICODE}NotEmptyASCII7ToUnicodeString{$ENDIF}(FRawPlanName));
        Exit;
      end;
    lcExecPrepStmt:
      Result := FPlainDriver.ExecPrepared(FConnectionHandle,
        PAnsiChar(FRawPlanName), InParamCount, FPQparamValues,
        FPQparamLengths, FPQparamFormats, 0);
    lcUnprepStmt:
      if Assigned(FConnectionHandle) then
        Result := FPlainDriver.ExecuteQuery(FConnectionHandle, PAnsiChar(SQL))
      else Result := nil;
    else
      Result := FPlainDriver.ExecuteQuery(FConnectionHandle, PAnsiChar(SQL));
  end;
  if Assigned(FConnectionHandle) then
    CheckPostgreSQLError(Connection, FPlainDriver, FConnectionHandle,
      LoggingCategory, LogSQL, Result);
end;
procedure TZPostgreSQLCAPIPreparedStatement.SetPlanNames;
begin
  FRawPlanName := IntToRaw(Int64(Hash(ASQL)+Cardinal(FStatementId)+NativeUInt(FConnectionHandle)));
end;

procedure TZPostgreSQLCAPIPreparedStatement.SetASQL(const Value: RawByteString);
begin
  if Prepared and ( ASQL <> Value ) then
    Unprepare;
  inherited SetASQL(Value);
end;

procedure TZPostgreSQLCAPIPreparedStatement.SetWSQL(const Value: ZWideString);
begin
  if Prepared and ( WSQL <> Value ) then
    Unprepare;
  inherited SetWSQL(Value);
end;

procedure TZPostgreSQLCAPIPreparedStatement.PrepareInParameters;
begin
  if not (Findeterminate_datatype) then
  begin
    SetLength(FPQparamValues, InParamCount);
    SetLength(FPQparamLengths, InParamCount);
    SetLength(FPQparamFormats, InParamCount);
  end;
end;

procedure TZPostgreSQLCAPIPreparedStatement.BindInParameters;
var
  TempBlob: IZBlob;
  WriteTempBlob: IZPostgreSQLOidBlob;
  ParamIndex: Integer;

  procedure UpdateNull(const Index: Integer);
  begin
    FPQparamValues[Index] := nil;
    FPQparamLengths[Index] := 0;
    FPQparamFormats[Index] := 0;
  end;

  procedure UpdatePAnsiChar(const Value: PAnsiChar; Const Index: Integer);
  begin
    UpdateNull(Index);
    FPQparamValues[Index] := Value;
    {EH: sade.., PG ignores Length settings for string even if it could speed up
      the speed by having a known size instead of checking for #0 terminator}
  end;

  procedure UpdateBinary(Value: Pointer; const Len, Index: Integer);
  begin
    UpdateNull(Index);

    FPQparamValues[Index] := Value;
    FPQparamLengths[Index] := Len;
    FPQparamFormats[Index] := 1;
  end;

begin
  if InParamCount <> High(FPQparamValues)+1 then
    raise EZSQLException.Create(SInvalidInputParameterCount);

  for ParamIndex := 0 to InParamCount -1 do
  begin
    if ClientVarManager.IsNull(InParamValues[ParamIndex])  then
      UpdateNull(ParamIndex)
    else
      {EH: Nice advanteges of the TZVariant:
        a string(w.Type ever) needs to be localized. So i simply reuse this
        values as vars and have a constant pointer ((: }
      case InParamTypes[ParamIndex] of
        stBoolean,
        stByte, stShort, stInteger, stLong,
        stBigDecimal, stFloat, stDouble,
        stString, stUnicodeString:
          UpdatePAnsiChar(ClientVarManager.GetAsCharRec(InParamValues[ParamIndex], ConSettings^.ClientCodePage^.CP).P, ParamIndex);
        stBytes:
          begin
            InParamValues[ParamIndex].VBytes := ClientVarManager.GetAsBytes(InParamValues[ParamIndex]);
            UpdateBinary(Pointer(InParamValues[ParamIndex].VBytes), Length(InParamValues[ParamIndex].VBytes), ParamIndex);
          end;
        stDate:
          begin
            InParamValues[ParamIndex].VRawByteString := DateTimeToRawSQLDate(ClientVarManager.GetAsDateTime(InParamValues[ParamIndex]),
              ConSettings^.WriteFormatSettings, False);
            UpdatePAnsiChar(PAnsiChar(InParamValues[ParamIndex].VRawByteString), ParamIndex);
          end;
        stTime:
          begin
            InParamValues[ParamIndex].VRawByteString := DateTimeToRawSQLTime(ClientVarManager.GetAsDateTime(InParamValues[ParamIndex]),
              ConSettings^.WriteFormatSettings, False);
            UpdatePAnsiChar(PAnsiChar(InParamValues[ParamIndex].VRawByteString), ParamIndex);
          end;
        stTimestamp:
          begin
            InParamValues[ParamIndex].VRawByteString := DateTimeToRawSQLTimeStamp(ClientVarManager.GetAsDateTime(InParamValues[ParamIndex]),
              ConSettings^.WriteFormatSettings, False);
            UpdatePAnsiChar(PAnsiChar(InParamValues[ParamIndex].VRawByteString), ParamIndex);
          end;
        stAsciiStream, stUnicodeStream, stBinaryStream:
          begin
            TempBlob := ClientVarManager.GetAsInterface(InParamValues[ParamIndex]) as IZBlob;
            if TempBlob.IsEmpty then
              UpdateNull(ParamIndex)
            else
              case InParamTypes[ParamIndex] of
                stBinaryStream:
                  if Foidasblob then
                  begin
                    try
                      WriteTempBlob := TZPostgreSQLOidBlob.Create(FPlainDriver, nil, 0,
                        FConnectionHandle, 0, ChunkSize);
                      WriteTempBlob.WriteBuffer(TempBlob.GetBuffer, TempBlob.Length);
                      InParamValues[ParamIndex].VRawByteString := IntToRaw(WriteTempBlob.GetBlobOid);
                      UpdatePAnsiChar(PAnsiChar(InParamValues[ParamIndex].VRawByteString), ParamIndex);
                    finally
                      WriteTempBlob := nil;
                    end;
                  end
                  else
                    UpdateBinary(TempBlob.GetBuffer, TempBlob.Length, ParamIndex);
                stAsciiStream, stUnicodeStream:
                  if TempBlob.IsClob then
                    UpdatePAnsiChar(TempBlob.GetPAnsiChar(ConSettings^.ClientCodePage^.CP), ParamIndex)
                  else
                  begin
                    InParamValues[ParamIndex].VRawByteString := GetValidatedAnsiStringFromBuffer(TempBlob.GetBuffer,
                      TempBlob.Length, ConSettings);
                    UpdatePAnsiChar(PAnsiChar(InParamValues[ParamIndex].VRawByteString), ParamIndex);
                  end;
              end; {case..}
          end;
      end;
  end;
  inherited BindInParameters;
end;

{**
  Removes eventual structures for binding input parameters.
}
procedure TZPostgreSQLCAPIPreparedStatement.UnPrepareInParameters;
begin
  { release allocated memory }
  if not (Findeterminate_datatype) then
  begin
    SetLength(FPQparamValues, 0);
    SetLength(FPQparamLengths, 0);
    SetLength(FPQparamFormats, 0);
  end;
end;

{**
  Prepares an SQL statement and inserts all data values.
  @return a prepared SQL statement.
}
function TZPostgreSQLCAPIPreparedStatement.PrepareAnsiSQLQuery: RawByteString;
var
  I: Integer;
  ParamIndex: Integer;
begin
  ParamIndex := 0;
  Result := '';
  for I := 0 to High(CachedQueryRaw) do
    if IsParamIndex[I] then
    begin
      if InParamCount <= ParamIndex then
        raise EZSQLException.Create(SInvalidInputParameterCount);
      Result := Result + PGPrepareAnsiSQLParam(InParamValues[ParamIndex],
        ClientVarManager, (Connection as IZPostgreSQLConnection), FPlainDriver,
        ChunkSize, InParamTypes[ParamIndex], Foidasblob, True, False, ConSettings);
      Inc(ParamIndex);
    end
    else
      Result := Result + CachedQueryRaw[i];
end;

procedure TZPostgreSQLCAPIPreparedStatement.Prepare;
var
  TempSQL: RawByteString;
  N, I: Integer;
begin
  if not Prepared then
  begin
    N := 0;

    for I := 0 to High(CachedQueryRaw) do
      if IsParamIndex[i] then
      begin
        Inc(N);
        TempSQL := TempSQL + '$' + IntToRaw(N);
      end else
        TempSQL := TempSQL + CachedQueryRaw[i];

    if ( N > 0 ) or ( ExecCount > 2 ) then //prepare only if Params are available or certain executions expected
    begin
      QueryHandle := ExecuteInternal(TempSQL, 'PREPARE '#39+SSQL+#39, lcPrepStmt);
      if not (Findeterminate_datatype) then
        FPlainDriver.Clear(QueryHandle);
      inherited Prepare;
    end;
  end;
end;

procedure TZPostgreSQLCAPIPreparedStatement.Unprepare;
var
  TempSQL: RawByteString;
begin
  if Prepared and Assigned(FPostgreSQLConnection.GetConnectionHandle) then
  begin
    inherited Unprepare;
    if (not Findeterminate_datatype)  then
    begin
      TempSQL := 'DEALLOCATE "'+FRawPlanName+'";';
      QueryHandle := ExecuteInternal(TempSQL, {$IFDEF UNICODE}NotEmptyASCII7ToUnicodeString{$ENDIF}(TempSQL), lcUnprepStmt);
      FPlainDriver.Clear(QueryHandle);
      FPostgreSQLConnection.UnregisterPreparedStmtName({$IFDEF UNICODE}NotEmptyASCII7ToUnicodeString{$ENDIF}(FRawPlanName));
    end;
  end;
end;

function TZPostgreSQLCAPIPreparedStatement.ExecuteQueryPrepared: IZResultSet;
begin
  Result := nil;

  Prepare;
  if Prepared  then
    if Findeterminate_datatype then
      QueryHandle := ExecuteInternal(PrepareAnsiSQLQuery, SSQL, lcExecute)
    else
    begin
      BindInParameters;
      QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecPrepStmt);
    end
  else
    QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecute);
  if QueryHandle <> nil then
    Result := CreateResultSet(QueryHandle)
  else
    Result := nil;
  inherited ExecuteQueryPrepared;
end;

function TZPostgreSQLCAPIPreparedStatement.ExecuteUpdatePrepared: Integer;
begin
  Result := -1;
  Prepare;

  if Prepared  then
    if Findeterminate_datatype then
      QueryHandle := ExecuteInternal(PrepareAnsiSQLQuery, SSQL, lcExecute)
    else
    begin
      BindInParameters;
      QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecPrepStmt);
    end
  else
    QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecute);

  if QueryHandle <> nil then
  begin
    Result := RawToIntDef(FPlainDriver.GetCommandTuples(QueryHandle), 0);
    FPlainDriver.Clear(QueryHandle);
  end;

  { Autocommit statement. }
  if Connection.GetAutoCommit then
    Connection.Commit;

  inherited ExecuteUpdatePrepared;
end;

function TZPostgreSQLCAPIPreparedStatement.ExecutePrepared: Boolean;
var
  ResultStatus: TZPostgreSQLExecStatusType;
begin
  Prepare;

  if Prepared  then
    if Findeterminate_datatype then
      QueryHandle := ExecuteInternal(PrepareAnsiSQLQuery, SSQL, lcExecPrepStmt)
    else
    begin
      BindInParameters;
      QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecPrepStmt);
    end
  else
    QueryHandle := ExecuteInternal(ASQL, SSQL, lcExecute);

  { Process queries with result sets }
  ResultStatus := FPlainDriver.GetResultStatus(QueryHandle);
  case ResultStatus of
    PGRES_TUPLES_OK:
      begin
        Result := True;
        LastResultSet := CreateResultSet(QueryHandle);
      end;
    PGRES_COMMAND_OK:
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
    else
      begin
        Result := False;
        LastUpdateCount := RawToIntDef(
          FPlainDriver.GetCommandTuples(QueryHandle), 0);
        FPlainDriver.Clear(QueryHandle);
      end;
  end;

  { Autocommit statement. }
  if not Result and Connection.GetAutoCommit then
    Connection.Commit;

  inherited ExecutePrepared;
end;


{ TZPostgreSQLCallableStatement }

{**
  Constructs this object and assignes the main properties.
  @param Connection a database connection object.
  @param Info a statement parameters.
  @param Handle a connection handle pointer.
}
constructor TZPostgreSQLCallableStatement.Create(
  Connection: IZConnection; const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  ResultSetType := rtScrollInsensitive;
  FPlainDriver := (Connection as IZPostgreSQLConnection).GetPlainDriver;
  Foidasblob := StrToBoolDef(Self.Info.Values['oidasblob'], False) or
    (Connection as IZPostgreSQLConnection).IsOidAsBlob;
end;

{**
  Provides connection handle from the associated IConnection
  @return a PostgreSQL connection handle.
}
function TZPostgreSQLCallableStatement.GetConnectionHandle:PZPostgreSQLConnect;
begin
  if Self.Connection = nil then
    Result := nil
  else
    Result := (self.Connection as IZPostgreSQLConnection).GetConnectionHandle;
end;

{**
  Creates a result set based on the current settings.
  @return a created result set object.
}
function TZPostgreSQLCallableStatement.CreateResultSet(const SQL: string;
      QueryHandle: PZPostgreSQLResult): IZResultSet;
var
  NativeResultSet: TZPostgreSQLResultSet;
  CachedResultSet: TZCachedResultSet;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  ConnectionHandle := GetConnectionHandle();
  NativeResultSet := TZPostgreSQLResultSet.Create(GetPlainDriver, Self, SQL,
    ConnectionHandle, QueryHandle, CachedLob, ChunkSize);
  NativeResultSet.SetConcurrency(rcReadOnly);
  if GetResultSetConcurrency = rcUpdatable then
  begin
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, SQL, nil,
      ConSettings);
    CachedResultSet.SetConcurrency(rcUpdatable);
    CachedResultSet.SetResolver(TZPostgreSQLCachedResolver.Create(
      Self,  NativeResultSet.GetMetadata));
    Result := CachedResultSet;
  end
  else
    Result := NativeResultSet;
end;

{**
   Returns plain draiver from connection object
   @return a PlainDriver object
}
function TZPostgreSQLCallableStatement.GetPlainDriver():IZPostgreSQLPlainDriver;
begin
  if self.Connection <> nil then
    Result := (self.Connection as IZPostgreSQLConnection).GetPlainDriver
  else
    Result := nil;
end;

{**
  Prepares an SQL parameter for the query.
  @param ParameterIndex the first parameter is 1, the second is 2, ...
  @return a string representation of the parameter.
}
function TZPostgreSQLCallableStatement.PrepareAnsiSQLParam(
  ParamIndex: Integer): RawByteString;
begin
  if InParamCount <= ParamIndex then
    raise EZSQLException.Create(SInvalidInputParameterCount);

  Result := PGPrepareAnsiSQLParam(InParamValues[ParamIndex], ClientVarManager,
    (Connection as IZPostgreSQLConnection), FPlainDriver, ChunkSize,
    InParamTypes[ParamIndex], Foidasblob, True, False, ConSettings);
end;

{**
  Executes an SQL statement that returns a single <code>ResultSet</code> object.
  @param sql typically this is a static SQL <code>SELECT</code> statement
  @return a <code>ResultSet</code> object that contains the data produced by the
    given query; never <code>null</code>
}
function TZPostgreSQLCallableStatement.ExecuteQuery(
  const SQL: RawByteString): IZResultSet;
var
  QueryHandle: PZPostgreSQLResult;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  Result := nil;
  ConnectionHandle := GetConnectionHandle();
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := GetPlainDriver.ExecuteQuery(ConnectionHandle,
    PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, GetPlainDriver, ConnectionHandle, lcExecute,
    LogSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, GetPlainDriver.GetProtocol, LogSQL);
  if QueryHandle <> nil then
  begin
    Result := CreateResultSet(SSQL, QueryHandle);
    FetchOutParams(Result);
  end
  else
    Result := nil;
end;

{**
  Prepares and executes an SQL statement that returns a single <code>ResultSet</code> object.
  @return a <code>ResultSet</code> object that contains the data produced by the
    given query; never <code>null</code>
}
function TZPostgreSQLCallableStatement.ExecuteQueryPrepared: IZResultSet;
begin
  TrimInParameters;
  Result := ExecuteQuery(FillParams(GetProcedureSql));
end;

{**
   Create sql string for calling stored procedure.
   @return a Stored Procedure SQL string
}
function TZPostgreSQLCallableStatement.GetProcedureSql: string;

  function GenerateParamsStr(Count: integer): string;
  var
    I: integer;
  begin
    Result := '';
    for I := 0 to Count - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + '?';
    end;
  end;

var
  InParams: string;
begin
  InParams := GenerateParamsStr(Length(InParamValues));
  Result := Format('SELECT * FROM %s(%s)', [SQL, InParams]);
end;

{**
   Fills the parameter (?) tokens with corresponding parameter value
   @return a prepared SQL query for execution
}
function TZPostgreSQLCallableStatement.FillParams(const ASql: String): RawByteString;
var I: Integer;
  Tokens: TStrings;
  ParamIndex: Integer;
begin
  if Pos('?', ASql) > 0 then
  begin
    Tokens := Connection.GetDriver.GetTokenizer.TokenizeBufferToList(ASql, [toUnifyWhitespaces]);
    try
      ParamIndex := 0;
      for I := 0 to Tokens.Count - 1 do
        if Tokens[I] = '?' then
        begin
          Result := Result + PrepareAnsiSQLParam(ParamIndex);
          Inc(ParamIndex);
        end
        else
          Result := Result + ZPlainString(Tokens[i]);
    finally
      Tokens.Free;
    end;
  end
  else
    Result := GetRawEncodedSQL(ASql);
end;

{**
  Executes an SQL <code>INSERT</code>, <code>UPDATE</code> or
  <code>DELETE</code> statement. In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @param sql an SQL <code>INSERT</code>, <code>UPDATE</code> or
    <code>DELETE</code> statement or an SQL statement that returns nothing
  @return either the row count for <code>INSERT</code>, <code>UPDATE</code>
    or <code>DELETE</code> statements, or 0 for SQL statements that return nothing
}
function TZPostgreSQLCallableStatement.ExecuteUpdate(const SQL: RawByteString): Integer;
var
  QueryHandle: PZPostgreSQLResult;
  ConnectionHandle: PZPostgreSQLConnect;
begin
  Result := -1;
  ConnectionHandle := GetConnectionHandle();
  ASQL := SQL; //Preprepares the SQL and Sets the AnsiSQL
  QueryHandle := GetPlainDriver.ExecuteQuery(ConnectionHandle,
    PAnsiChar(ASQL));
  CheckPostgreSQLError(Connection, GetPlainDriver, ConnectionHandle, lcExecute,
    SSQL, QueryHandle);
  DriverManager.LogMessage(lcExecute, GetPlainDriver.GetProtocol, SSQL);

  if QueryHandle <> nil then
  begin
    Result := RawToIntDef(GetPlainDriver.GetCommandTuples(QueryHandle), 0);
    FetchOutParams(CreateResultSet(SSQL, QueryHandle));
  end;

  { Autocommit statement. }
  if Connection.GetAutoCommit then
    Connection.Commit;
end;


function TZPostgreSQLCallableStatement.ExecuteUpdatePrepared: Integer;
begin
  TrimInParameters;
  Result := Self.ExecuteUpdate(FillParams(GetProcedureSql));
end;

{**
  Sets output parameters from a ResultSet
  @param Value a IZResultSet object.
}
procedure TZPostgreSQLCallableStatement.FetchOutParams(ResultSet: IZResultSet);
var
  ParamIndex, I: Integer;
  HasRows: Boolean;
begin
  ResultSet.BeforeFirst;
  HasRows := ResultSet.Next;

  I := 1;
  for ParamIndex := 0 to OutParamCount - 1 do
  begin
    if not (FDBParamTypes[ParamIndex] in [2, 3, 4]) then // ptOutput, ptInputOutput, ptResult
      Continue;

    if I > ResultSet.GetMetadata.GetColumnCount then
      Break;

    if (not HasRows) or (ResultSet.IsNull(I)) then
      OutParamValues[ParamIndex] := NullVariant
    else
      case ResultSet.GetMetadata.GetColumnType(I) of
      stBoolean:
        OutParamValues[ParamIndex] := EncodeBoolean(ResultSet.GetBoolean(I));
      stByte:
        OutParamValues[ParamIndex] := EncodeInteger(ResultSet.GetByte(I));
      stBytes:
        OutParamValues[ParamIndex] := EncodeBytes(ResultSet.GetBytes(I));
      stShort:
        OutParamValues[ParamIndex] := EncodeInteger(ResultSet.GetShort(I));
      stInteger:
        OutParamValues[ParamIndex] := EncodeInteger(ResultSet.GetInt(I));
      stLong:
        OutParamValues[ParamIndex] := EncodeInteger(ResultSet.GetLong(I));
      stFloat:
        OutParamValues[ParamIndex] := EncodeFloat(ResultSet.GetFloat(I));
      stDouble:
        OutParamValues[ParamIndex] := EncodeFloat(ResultSet.GetDouble(I));
      stBigDecimal:
        OutParamValues[ParamIndex] := EncodeFloat(ResultSet.GetBigDecimal(I));
      stString, stAsciiStream:
        OutParamValues[ParamIndex] := EncodeString(ResultSet.GetString(I));
      stUnicodeString, stUnicodeStream:
        OutParamValues[ParamIndex] := EncodeUnicodeString(ResultSet.GetUnicodeString(I));
      stDate:
        OutParamValues[ParamIndex] := EncodeDateTime(ResultSet.GetDate(I));
      stTime:
        OutParamValues[ParamIndex] := EncodeDateTime(ResultSet.GetTime(I));
      stTimestamp:
        OutParamValues[ParamIndex] := EncodeDateTime(ResultSet.GetTimestamp(I));
      stBinaryStream:
        OutParamValues[ParamIndex] := EncodeInterface(ResultSet.GetBlob(I));
      else
        OutParamValues[ParamIndex] := EncodeString(ResultSet.GetString(I));
      end;
    Inc(I);
  end;
  ResultSet.BeforeFirst;
end;

{**
   Function removes ptResult, ptOutput parameters from
   InParamTypes and InParamValues
}
procedure TZPostgreSQLCallableStatement.TrimInParameters;
var
  I: integer;
  ParamValues: TZVariantDynArray;
  ParamTypes: TZSQLTypeArray;
  ParamCount: Integer;
begin
  ParamCount := 0;
  SetLength(ParamValues, InParamCount);
  SetLength(ParamTypes, InParamCount);

  for I := 0 to High(InParamTypes) do
  begin
    if (Self.FDBParamTypes[i] in [2, 4]) then //[ptResult, ptOutput]
      Continue;
    ParamTypes[ParamCount] := InParamTypes[I];
    ParamValues[ParamCount] := InParamValues[I];
    Inc(ParamCount);
  end;

  if ParamCount = InParamCount then
    Exit;

  InParamTypes := ParamTypes;
  InParamValues := ParamValues;
  SetInParamCount(ParamCount);
end;

{ TZPostgreSQLCachedResolver }

{**
  Checks is the specified column can be used in where clause.
  @param ColumnIndex an index of the column.
  @returns <code>true</code> if column can be included into where clause.
}
function TZPostgreSQLCachedResolver.CheckKeyColumn(ColumnIndex: Integer): Boolean;
begin
  Result := (Metadata.GetTableName(ColumnIndex) <> '')
    and (Metadata.GetColumnName(ColumnIndex) <> '')
    and Metadata.IsSearchable(ColumnIndex)
    and not (Metadata.GetColumnType(ColumnIndex)
    in [stUnknown, stBinaryStream, stUnicodeStream]);
end;



end.
