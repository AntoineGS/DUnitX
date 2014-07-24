{***************************************************************************}
{                                                                           }
{           DUnitX                                                          }
{                                                                           }
{           Copyright (C) 2013 Vincent Parrett                              }
{                                                                           }
{           vincent@finalbuilder.com                                        }
{           http://www.finalbuilder.com                                     }
{                                                                           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

unit DUnitX.CategoryExpression;
//This unit is largely a port of the NUnit CategoryExpression class

interface

uses
  DUnitX.Extensibility,
  DUnitX.Filters;

{$I DUnitX.inc}

type
  /// <summary>
	/// CategoryExpression parses strings representing boolean
	/// combinations of categories according to the following
	/// grammar:
	///   CategoryName ::= string not containing any of ',', '&', '+', '-'
	///   CategoryFilter ::= CategoryName | CategoryFilter ',' CategoryName
	///   CategoryPrimitive ::= CategoryFilter | '-' CategoryPrimitive
	///   CategoryTerm ::= CategoryPrimitive | CategoryTerm '&' CategoryPrimitive
	/// </summary>
  TCategoryExpression = class
  private
    FText : string;
    FNext  : integer;
    FToken : string;
    FFilter : ITestFilter;
  protected
    function GetTerm: ITestFilter;
    function GetExpression: ITestFilter;
    function GetCategoryFilter: ICategoryFilter;
    function GetPrimitive: ITestFilter;
    function GetToken: string;
    function NextIsOperator: boolean;
    procedure SkipWhiteSpace;
    function EndOfText : boolean;
    function GetFilter: ITestFilter;
    constructor Create(const text : string);
  public
    class function CreateFilter(const text : string) : ITestFilter;
  end;

implementation

uses
  Character,
  SysUtils,
  StrUtils;

const
  Operators : array[1..7] of Char = (',', ';', '-', '|', '+', '(', ')') ;

{ TCategoryExpression }

constructor TCategoryExpression.Create(const text: string);
begin
  FText := text;
  if FText <> ''then
    FNext := 1
  else
    FNext := MaxInt; //force end of text
end;

class function TCategoryExpression.CreateFilter(const text : string): ITestFilter;
var
  expr : TCategoryExpression;
begin
  expr := TCategoryExpression.Create(text);
  try
    result := expr.GetFilter;
  finally
    expr.Free;
  end;
end;


function IndexOfAny(const value : string; const AnyOf: array of Char; StartIndex : Integer): Integer;
var
  i, j : Integer;
  c: Char;
  Max: Integer;
begin
  Max := Length(value);
  i := StartIndex;
  while i < Max do
  begin
    for j := 0 to Length(AnyOf) -1 do
    begin
      c := AnyOf[j];
      if value[i] = c then
        Exit(i);
    end;
    Inc(i);
  end;
  Result := -1;
end;

function TCategoryExpression.GetExpression : ITestFilter;
var
  orFilter : IOrFilter;
begin
  result := GetTerm;
  if FToken <> '|' then
    exit;
	orFilter := TOrFilter.Create(result);
  while FToken = '|'  do
  begin
    GetToken();
    orFilter.Add(GetTerm());
  end;
  result := orFilter;
end;

function TCategoryExpression.GetTerm : ITestFilter;
var
  filter : IAndFilter;
  prim : ITestFilter;
  tok : string;
begin
  prim := GetPrimitive;
  if ( FToken <> '+') and (FToken <> '-' ) then
    exit(prim);

  filter := TAndFilter.Create(prim);

  while ( FToken = '+') or (FToken = '-' ) do
  begin
    tok := FToken;
    GetToken();
    prim := GetPrimitive();
    if tok = '-' then
      filter.Add(TNotFilter.Create(prim) as ITestFilter)
    else
      filter.Add(prim);
  end;

  result := filter;
end;


function TCategoryExpression.GetPrimitive : ITestFilter;
begin
  if FToken = '-' then
  begin
    GetToken;
    result := TNotFilter.Create(GetPrimitive);
    exit;
  end
  else if FToken = '(' then
  begin
    GetToken; // Skip (
    result := GetExpression;
    GetToken(); // Skip ')'
    exit;
  end;

  result := GetCategoryFilter;
end;



function  TCategoryExpression.GetCategoryFilter : ICategoryFilter;
begin
  result := TCategoryFilter.Create(FToken);
  while( (GetToken = ',') or (FToken = ';' )) do
    result.Add(GetToken);
end;


function TCategoryExpression.GetToken : string;
var
  idx   : integer;
begin
  SkipWhiteSpace;

  if EndOfText then
    FToken := ''
  else if NextIsOperator then
  begin
    FToken := Copy(FText, FNext, 1);
    Inc(FNext);
  end
  else
  begin
    idx := IndexOfAny(FText, Operators, FNext);
    if idx < 0  then
       idx := Length(FText) + 1;

    FToken := TrimRight(Copy(FText,FNext, idx - FNext));
    FNext := idx;
  end;
  result := FToken;
end;

function TCategoryExpression.EndOfText : boolean;
begin
	 result :=  FNext > Length(FText);
end;

procedure TCategoryExpression.SkipWhiteSpace;
begin
  while( (FNext < Length(Ftext)) and TCharacter.IsWhiteSpace(FText [FNext] ) ) do
    Inc(FNext);
end;

function TCategoryExpression.NextIsOperator : boolean;
var
  op : Char;
begin
  result := false;
  if not EndOfText then
  begin
    for op in Operators do
    begin
      if FText[FNext] = op then
        Exit(true);
    end;
  end;
end;

function TCategoryExpression.GetFilter: ITestFilter;
begin
  if FFilter <> nil then
    exit(FFilter);

  if GetToken = '' then
    FFilter := TEmptyFilter.Create
  else
    FFilter := GetExpression;
  Result := FFilter;
end;

end.
