{
  K2040 xEdit JSON Exporter v1.6

  Purpose:
    Export the decoded xEdit tree of ESP/ESL/ESM plugins to JSON.
    This is a general-purpose, read-only exporter.

  How to use:
    1. Place this file in your xEdit/Edit Scripts folder.
       For Fallout 4 this is usually:
         FO4Edit\Edit Scripts\
    2. Load your plugin and its masters in xEdit.
    3. Select a whole plugin, a group, one record, or multiple records.
    4. Right-click -> Apply Script -> K2040_xEdit_JSON_Exporter_v1_6.
    5. Choose an output filename, or leave blank for:
       <PluginName>[_SIGNATURES].json

  Notes:
    - Read-only exporter. It does not modify records.
    - Exports all main record signatures.
    - Preserves arrays as arrays.
    - Preserves nested xEdit child structure.
    - Adds exportValidation with header-count comparison and signature breakdown.
    - Contains no project-specific logic.
    - v1.1 resolved bare and relative output paths under xEdit's ScriptsPath.
    - v1.2 handled directory-only output input by appending the automatic filename.
    - v1.3 added a brief exportSummary header with readable record type counts.
    - v1.4 shortened automatic names and added selected-record signatures to filenames.
    - v1.5 fixes full-plugin auto naming so full ESP/ESL/ESM exports do not append every exported signature.
    - v1.6 preserves repeated same-name child elements without silent overwrite.
}

unit K2040_xEdit_JSON_Exporter_v1_6;

var
  JSONFile       : String;
  AutoOutputFileName: String;
  JSONData       : TJsonObject;
  JSONElement    : IInterface;
  ArrayTypes     : array[0..1] of TwbElementType;
  ScalarTypes    : array[0..2] of TwbElementType;
  ScalarPatch    : array[0..4] of String;
  UICount        : Integer;
  Progress       : Integer;
  ExportedRecords: Integer;
  SelectionExported: Boolean;
  SelectedRecordCount: Integer;
  SignatureCounts : TStringList;
  DetectedGroups  : TStringList;
  SelectedSignatures: TStringList;
  TES4HeaderRecordCount: String;
  TES4ExportedRecordCount: Integer;

procedure InitTypeHelpers;
begin
  ArrayTypes[0] := etArray;
  ArrayTypes[1] := etSubRecordArray;

  ScalarTypes[0] := etValue;
  ScalarTypes[1] := etFlag;
  ScalarTypes[2] := etSubRecord;

  // xEdit can report some structured fields as scalar-like element types.
  // These names should remain structured when they contain child data.
  ScalarPatch[0] := 'CTDA - CTDA';
  ScalarPatch[1] := 'TRDA - Response Data';
  ScalarPatch[2] := 'ONAM - Overridden Forms';
  ScalarPatch[3] := 'HEDR - Header';
  ScalarPatch[4] := 'VMAD - Virtual Machine Adapter';
end;

function LogProgress(value: Integer): Integer;
begin
  value := value + 1;
  if value mod UICount = 0 then
    AddMessage('Processed ' + IntToStr(value) + ' elements...');
  Result := value;
end;

function TwbElementTypeToString(data: TwbElementType): String;
begin
  Result := 'UNKNOWN';

  if data = etFile then Result := 'etFile';
  if data = etMainRecord then Result := 'etMainRecord';
  if data = etGroupRecord then Result := 'etGroupRecord';
  if data = etSubRecord then Result := 'etSubRecord';
  if data = etSubRecordStruct then Result := 'etSubRecordStruct';
  if data = etSubRecordArray then Result := 'etSubRecordArray';
  if data = etSubRecordUnion then Result := 'etSubRecordUnion';
  if data = etArray then Result := 'etArray';
  if data = etStruct then Result := 'etStruct';
  if data = etValue then Result := 'etValue';
  if data = etFlag then Result := 'etFlag';
  if data = etStringListTerminator then Result := 'etStringListTerminator';
  if data = etUnion then Result := 'etUnion';
  if data = etStructChapter then Result := 'etStructChapter';
end;

function SafeBaseName(e: IInterface): String;
begin
  Result := '';
  try
    Result := BaseName(e);
  except
    Result := '';
  end;
end;

function SafeName(e: IInterface): String;
begin
  Result := '';
  try
    Result := Name(e);
  except
    Result := '';
  end;
end;

function SafePath(e: IInterface): String;
begin
  Result := '';
  try
    Result := Path(e);
  except
    Result := '';
  end;
end;

function SafeFullPath(e: IInterface): String;
begin
  Result := '';
  try
    Result := FullPath(e);
  except
    Result := '';
  end;
end;

function SafeEditValue(e: IInterface): String;
begin
  Result := '';
  try
    Result := GetEditValue(e);
  except
    Result := '';
  end;
end;

function SafeElementEditValueByPath(e: IInterface; elementPath: String): String;
begin
  Result := '';
  try
    Result := GetElementEditValues(e, elementPath);
  except
    Result := '';
  end;
end;

function SafeSignature(e: IInterface): String;
begin
  Result := '';
  try
    Result := Signature(e);
  except
    Result := '';
  end;
end;

function SafeEditorID(e: IInterface): String;
begin
  Result := '';
  try
    Result := EditorID(e);
  except
    Result := '';
  end;
end;

function SafeFullName(e: IInterface): String;
begin
  Result := '';
  try
    Result := GetElementEditValues(e, 'FULL - Name');
  except
    Result := '';
  end;

  if Result = '' then begin
    try
      Result := GetElementEditValues(e, 'FULL');
    except
      Result := '';
    end;
  end;
end;

function SafeFormID(e: IInterface): String;
begin
  Result := '';
  try
    Result := IntToHex(FormID(e), 8);
  except
    Result := '';
  end;
end;

function SafeFixedFormID(e: IInterface): String;
begin
  Result := '';
  try
    Result := IntToHex(FixedFormID(e), 8);
  except
    Result := '';
  end;
end;

function SafeFileName(e: IInterface): String;
var
  f: IInterface;
begin
  Result := '';
  try
    f := GetFile(e);
    if Assigned(f) then
      Result := GetFileName(f);
  except
    Result := '';
  end;
end;

function IsFile(e: IInterface): Boolean;
begin
  Result := False;
  try
    // xEdit does not always report file elements reliably through etFile here.
    if SafeBaseName(e) = '[TES4:00000000]' then
      Result := True;
  except
    Result := False;
  end;
end;

function IsMain(e: IInterface): Boolean;
begin
  Result := False;
  try
    if ElementType(e) = etMainRecord then
      Result := True;
  except
    Result := False;
  end;
end;

function IsArray(e: IInterface): Boolean;
var
  index: Integer;
begin
  Result := False;

  for index := 0 to Length(ArrayTypes) - 1 do begin
    try
      if ArrayTypes[index] = ElementType(e) then
        Result := True;
    except
    end;
  end;

  // xEdit occasionally reports this in a way that benefits from explicit array handling.
  if SafeBaseName(e) = 'ONAM - Overridden Forms' then
    Result := True;
end;

function IsScalar(e: IInterface): Boolean;
var
  index: Integer;
begin
  Result := False;

  // If xEdit exposes children, keep this as a structured object even if the
  // reported element type looks scalar.
  if ElementCount(e) > 0 then
    Exit;

  for index := 0 to Length(ScalarTypes) - 1 do begin
    try
      if ScalarTypes[index] = ElementType(e) then
        Result := True;
    except
    end;
  end;

  for index := 0 to Length(ScalarPatch) - 1 do begin
    if ScalarPatch[index] = SafeBaseName(e) then
      Result := False;
  end;
end;

function IsNativeGroupRecord(e: IInterface): Boolean;
begin
  Result := False;
  try
    if ElementType(e) = etGroupRecord then
      Result := True;
  except
    Result := False;
  end;
end;

procedure CollectRepeatedChildBaseNames(e: IInterface; repeatedNames: TStringList);
var
  index: Integer;
  child: IInterface;
  key: String;
  seenNames: TStringList;
begin
  repeatedNames.Clear;

  seenNames := TStringList.Create;
  try
    for index := 0 to ElementCount(e) - 1 do begin
      child := ElementByIndex(e, index);

      if Assigned(child) and (not IsNativeGroupRecord(child)) then begin
        key := SafeBaseName(child);

        if seenNames.IndexOf(key) >= 0 then begin
          if repeatedNames.IndexOf(key) < 0 then
            repeatedNames.Add(key);
        end
        else
          seenNames.Add(key);
      end;
    end;
  finally
    seenNames.Free;
  end;
end;

procedure AddRecordMeta(e: IInterface; data: TJsonObject);
begin
  data.S['_recordSignature'] := SafeSignature(e);
  data.S['_formIdLoadOrder'] := SafeFormID(e);
  data.S['_formIdFixed'] := SafeFixedFormID(e);
  data.S['_editorId'] := SafeEditorID(e);
  data.S['_fullName'] := SafeFullName(e);
  data.S['_sourceFile'] := SafeFileName(e);
  data.S['_xEditName'] := SafeName(e);
  data.S['_xEditPath'] := SafePath(e);
  data.S['_xEditFullPath'] := SafeFullPath(e);
end;

procedure ScalarToJSON(e: IInterface; data: TJsonObject);
begin
  data.S[SafeBaseName(e)] := SafeEditValue(e);
end;

procedure ChildrenToJSON(e: IInterface; data: TJsonObject);
var
  index: Integer;
  child: IInterface;
  key: String;
  item: TJsonObject;
  repeatedNames: TStringList;
begin
  repeatedNames := TStringList.Create;
  try
    CollectRepeatedChildBaseNames(e, repeatedNames);

    for index := 0 to ElementCount(e) - 1 do begin
      child := ElementByIndex(e, index);

      if Assigned(child) and (not IsNativeGroupRecord(child)) then begin
        key := SafeBaseName(child);

        if repeatedNames.IndexOf(key) >= 0 then begin
          item := data.A[key].AddObject;
          ElementToJSON(child, item);
        end
        else
          ElementToJSON(child, data);
      end;
    end;
  finally
    repeatedNames.Free;
  end;
end;

procedure ObjectToJSON(e: IInterface; data: TJsonObject);
var
  node : TJsonObject;
begin
  node := data.O[SafeBaseName(e)];
  node.S['_xEditElementName'] := SafeName(e);
  node.S['_xEditElementType'] := TwbElementTypeToString(ElementType(e));
  node.S['_xEditElementPath'] := SafePath(e);

  ChildrenToJSON(e, node);
end;

procedure ArrayToJSON(e: IInterface; data: TJsonObject);
var
  index: Integer;
  child: IInterface;
  node : TJsonObject;
  item : TJsonObject;
begin
  node := data.O[SafeBaseName(e)];
  node.S['_xEditElementName'] := SafeName(e);
  node.S['_xEditElementType'] := TwbElementTypeToString(ElementType(e));
  node.S['_xEditElementPath'] := SafePath(e);

  for index := 0 to ElementCount(e) - 1 do begin
    child := ElementByIndex(e, index);
    if Assigned(child) and (not IsNativeGroupRecord(child)) then begin
      item := node.A['items'].AddObject;
      ElementToJSON(child, item);
    end;
  end;
end;

function StartsWithText(value: String; prefix: String): Boolean;
begin
  Result := False;
  if Copy(value, 1, Length(prefix)) = prefix then
    Result := True;
end;

function StoredField(line: String; fieldIndex: Integer): String;
var
  i, currentField, startPos: Integer;
begin
  Result := '';
  currentField := 0;
  startPos := 1;

  for i := 1 to Length(line) + 1 do begin
    if (i > Length(line)) or (Copy(line, i, 1) = #9) then begin
      if currentField = fieldIndex then begin
        Result := Copy(line, startPos, i - startPos);
        Exit;
      end;

      currentField := currentField + 1;
      startPos := i + 1;
    end;
  end;
end;

function RemoveLeadingPathIndex(value: String): String;
var
  p: Integer;
begin
  Result := Trim(value);

  if Copy(Result, 1, 1) = '[' then begin
    p := Pos(']', Result);

    if p > 0 then
      Result := Trim(Copy(Result, p + 1, Length(Result) - p));
  end;
end;

procedure AddDetectedGroupKey(groupKey: String);
begin
  if groupKey = '' then
    Exit;

  if not Assigned(DetectedGroups) then
    Exit;

  if DetectedGroups.IndexOf(groupKey) < 0 then
    DetectedGroups.Add(groupKey);
end;

procedure CollectGroupContainersFromFullPath(fullPath: String);
var
  i, startPos: Integer;
  part: String;
  normalized: String;
begin
  if fullPath = '' then
    Exit;

  startPos := 1;

  for i := 1 to Length(fullPath) + 1 do begin
    if (i > Length(fullPath)) or (Copy(fullPath, i, 1) = '\') then begin
      part := Trim(Copy(fullPath, startPos, i - startPos));
      normalized := RemoveLeadingPathIndex(part);

      if StartsWithText(normalized, 'GRUP ') then
        AddDetectedGroupKey(normalized);

      startPos := i + 1;
    end;
  end;
end;

function SignatureCountIndex(sig: String): Integer;
var
  i: Integer;
begin
  Result := -1;

  if not Assigned(SignatureCounts) then
    Exit;

  for i := 0 to SignatureCounts.Count - 1 do begin
    if StoredField(SignatureCounts[i], 0) = sig then begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure IncrementSignatureCount(sig: String);
var
  idx: Integer;
  countValue: Integer;
begin
  if sig = '' then
    sig := 'UNKNOWN';

  if not Assigned(SignatureCounts) then
    Exit;

  idx := SignatureCountIndex(sig);

  if idx < 0 then begin
    SignatureCounts.Add(sig + #9 + '1');
  end
  else begin
    countValue := StrToIntDef(StoredField(SignatureCounts[idx], 1), 0);
    countValue := countValue + 1;
    SignatureCounts[idx] := sig + #9 + IntToStr(countValue);
  end;
end;

procedure UpdateExportValidationForRecord(e: IInterface);
var
  sig: String;
  headerCountValue: String;
begin
  sig := SafeSignature(e);

  IncrementSignatureCount(sig);
  CollectGroupContainersFromFullPath(SafeFullPath(e));

  if sig = 'TES4' then begin
    TES4ExportedRecordCount := TES4ExportedRecordCount + 1;

    if TES4HeaderRecordCount = '' then begin
      headerCountValue := SafeElementEditValueByPath(e, 'HEDR - Header\Number of Records');

      if headerCountValue = '' then
        headerCountValue := SafeElementEditValueByPath(e, 'Record Header\HEDR - Header\Number of Records');

      TES4HeaderRecordCount := headerCountValue;
    end;
  end;
end;

procedure WriteSignatureCountsToValidation(data: TJsonObject);
var
  i: Integer;
  sig: String;
  countValue: String;
begin
  if not Assigned(SignatureCounts) then
    Exit;

  for i := 0 to SignatureCounts.Count - 1 do begin
    sig := StoredField(SignatureCounts[i], 0);
    countValue := StoredField(SignatureCounts[i], 1);

    if sig <> '' then
      data.O['recordSignatures'].S[sig] := countValue;
  end;
end;


function RecordSignatureDisplayName(sig: String): String;
begin
  Result := sig;

  if sig = 'TES4' then Result := 'Plugin Header';
  if sig = 'GMST' then Result := 'Game Setting';
  if sig = 'KYWD' then Result := 'Keyword';
  if sig = 'LCRT' then Result := 'Location Reference Type';
  if sig = 'AACT' then Result := 'Action';
  if sig = 'TRNS' then Result := 'Transform';
  if sig = 'CMPO' then Result := 'Component';
  if sig = 'TXST' then Result := 'Texture Set';
  if sig = 'MICN' then Result := 'Menu Icon';
  if sig = 'GLOB' then Result := 'Global Variable';
  if sig = 'DMGT' then Result := 'Damage Type';
  if sig = 'CLAS' then Result := 'Class';
  if sig = 'FACT' then Result := 'Faction';
  if sig = 'HDPT' then Result := 'Head Part';
  if sig = 'EYES' then Result := 'Eyes';
  if sig = 'RACE' then Result := 'Race';
  if sig = 'SOUN' then Result := 'Sound';
  if sig = 'ASPC' then Result := 'Acoustic Space';
  if sig = 'SKIL' then Result := 'Skill';
  if sig = 'MGEF' then Result := 'Magic Effect';
  if sig = 'SCPT' then Result := 'Script';
  if sig = 'LTEX' then Result := 'Landscape Texture';
  if sig = 'ENCH' then Result := 'Object Effect';
  if sig = 'SPEL' then Result := 'Spell';
  if sig = 'SCRL' then Result := 'Scroll';
  if sig = 'ACTI' then Result := 'Activator';
  if sig = 'TACT' then Result := 'Talking Activator';
  if sig = 'ARMO' then Result := 'Armor';
  if sig = 'BOOK' then Result := 'Book';
  if sig = 'CONT' then Result := 'Container';
  if sig = 'DOOR' then Result := 'Door';
  if sig = 'INGR' then Result := 'Ingredient';
  if sig = 'LIGH' then Result := 'Light';
  if sig = 'MISC' then Result := 'Miscellaneous Item';
  if sig = 'STAT' then Result := 'Static';
  if sig = 'SCOL' then Result := 'Static Collection';
  if sig = 'MSTT' then Result := 'Moveable Static';
  if sig = 'PWAT' then Result := 'Placeable Water';
  if sig = 'GRAS' then Result := 'Grass';
  if sig = 'TREE' then Result := 'Tree';
  if sig = 'FLOR' then Result := 'Flora';
  if sig = 'FURN' then Result := 'Furniture';
  if sig = 'WEAP' then Result := 'Weapon';
  if sig = 'AMMO' then Result := 'Ammunition';
  if sig = 'NPC_' then Result := 'Non-Player Character';
  if sig = 'LVLN' then Result := 'Leveled NPC';
  if sig = 'KEYM' then Result := 'Key';
  if sig = 'ALCH' then Result := 'Ingestible';
  if sig = 'IDLM' then Result := 'Idle Marker';
  if sig = 'NOTE' then Result := 'Note';
  if sig = 'COBJ' then Result := 'Constructible Object';
  if sig = 'PROJ' then Result := 'Projectile';
  if sig = 'HAZD' then Result := 'Hazard';
  if sig = 'BNDS' then Result := 'Bendable Spline';
  if sig = 'SLGM' then Result := 'Soul Gem';
  if sig = 'TERM' then Result := 'Terminal';
  if sig = 'LVLI' then Result := 'Leveled Item';
  if sig = 'WTHR' then Result := 'Weather';
  if sig = 'CLMT' then Result := 'Climate';
  if sig = 'SPGD' then Result := 'Shader Particle Geometry';
  if sig = 'RFCT' then Result := 'Visual Effect';
  if sig = 'REGN' then Result := 'Region';
  if sig = 'NAVI' then Result := 'Navigation Mesh Info Map';
  if sig = 'CELL' then Result := 'Cell';
  if sig = 'REFR' then Result := 'Placed Object';
  if sig = 'ACHR' then Result := 'Placed NPC';
  if sig = 'PMIS' then Result := 'Placed Missile';
  if sig = 'PGRE' then Result := 'Placed Grenade';
  if sig = 'PBEA' then Result := 'Placed Beam';
  if sig = 'PFLA' then Result := 'Placed Flame';
  if sig = 'PCON' then Result := 'Placed Cone/Voice';
  if sig = 'PBAR' then Result := 'Placed Barrier';
  if sig = 'PHZD' then Result := 'Placed Hazard';
  if sig = 'WRLD' then Result := 'Worldspace';
  if sig = 'LAND' then Result := 'Landscape';
  if sig = 'NAVM' then Result := 'Navigation Mesh';
  if sig = 'TLOD' then Result := 'Texture LOD';
  if sig = 'DIAL' then Result := 'Dialog Topic';
  if sig = 'INFO' then Result := 'Dialog Response';
  if sig = 'QUST' then Result := 'Quest';
  if sig = 'IDLE' then Result := 'Idle Animation';
  if sig = 'PACK' then Result := 'Package';
  if sig = 'CSTY' then Result := 'Combat Style';
  if sig = 'LSCR' then Result := 'Load Screen';
  if sig = 'LVSP' then Result := 'Leveled Spell';
  if sig = 'ANIO' then Result := 'Animated Object';
  if sig = 'WATR' then Result := 'Water';
  if sig = 'EFSH' then Result := 'Effect Shader';
  if sig = 'TOFT' then Result := 'Topic Info';
  if sig = 'EXPL' then Result := 'Explosion';
  if sig = 'DEBR' then Result := 'Debris';
  if sig = 'IMGS' then Result := 'Image Space';
  if sig = 'IMAD' then Result := 'Image Space Modifier';
  if sig = 'FLST' then Result := 'Form List';
  if sig = 'PERK' then Result := 'Perk';
  if sig = 'BPTD' then Result := 'Body Part Data';
  if sig = 'ADDN' then Result := 'Addon Node';
  if sig = 'AVIF' then Result := 'Actor Value Information';
  if sig = 'CAMS' then Result := 'Camera Shot';
  if sig = 'CPTH' then Result := 'Camera Path';
  if sig = 'VTYP' then Result := 'Voice Type';
  if sig = 'MATT' then Result := 'Material Type';
  if sig = 'IPCT' then Result := 'Impact';
  if sig = 'IPDS' then Result := 'Impact Data Set';
  if sig = 'ARMA' then Result := 'Armor Addon';
  if sig = 'ECZN' then Result := 'Encounter Zone';
  if sig = 'LCTN' then Result := 'Location';
  if sig = 'MESG' then Result := 'Message';
  if sig = 'RGDL' then Result := 'Ragdoll';
  if sig = 'DOBJ' then Result := 'Default Object Manager';
  if sig = 'DFOB' then Result := 'Default Object';
  if sig = 'LGTM' then Result := 'Lighting Template';
  if sig = 'MUSC' then Result := 'Music Type';
  if sig = 'FSTP' then Result := 'Footstep';
  if sig = 'FSTS' then Result := 'Footstep Set';
  if sig = 'SMBN' then Result := 'Story Manager Branch Node';
  if sig = 'SMQN' then Result := 'Story Manager Quest Node';
  if sig = 'SMEN' then Result := 'Story Manager Event Node';
  if sig = 'DLBR' then Result := 'Dialog Branch';
  if sig = 'MUST' then Result := 'Music Track';
  if sig = 'DLVW' then Result := 'Dialog View';
  if sig = 'WOOP' then Result := 'Word of Power';
  if sig = 'SHOU' then Result := 'Shout';
  if sig = 'EQUP' then Result := 'Equip Type';
  if sig = 'RELA' then Result := 'Relationship';
  if sig = 'SCEN' then Result := 'Scene';
  if sig = 'ASTP' then Result := 'Association Type';
  if sig = 'OTFT' then Result := 'Outfit';
  if sig = 'ARTO' then Result := 'Art Object';
  if sig = 'MATO' then Result := 'Material Object';
  if sig = 'MOVT' then Result := 'Movement Type';
  if sig = 'SNDR' then Result := 'Sound Descriptor';
  if sig = 'DUAL' then Result := 'Dual Cast Data';
  if sig = 'SNCT' then Result := 'Sound Category';
  if sig = 'SOPM' then Result := 'Sound Output Model';
  if sig = 'COLL' then Result := 'Collision Layer';
  if sig = 'CLFM' then Result := 'Color Form';
  if sig = 'REVB' then Result := 'Reverb Parameters';
  if sig = 'PKIN' then Result := 'Pack-In';
  if sig = 'RFGP' then Result := 'Reference Group';
  if sig = 'AORU' then Result := 'Attraction Rule';
  if sig = 'SCSN' then Result := 'Sound Category Snapshot';
  if sig = 'STAG' then Result := 'Animation Sound Tag Set';
  if sig = 'NOCM' then Result := 'Navigation Obstacle Manager';
  if sig = 'LENS' then Result := 'Lens Flare';
  if sig = 'LSPR' then Result := 'Lens Flare Sprite';
  if sig = 'GDRY' then Result := 'God Rays';
  if sig = 'OVIS' then Result := 'Object Visibility Manager';
  if sig = 'OMOD' then Result := 'Object Modification';
  if sig = 'MSWP' then Result := 'Material Swap';
  if sig = 'ZOOM' then Result := 'Zoom Data';
  if sig = 'INNR' then Result := 'Instance Naming Rules';
  if sig = 'KSSM' then Result := 'Sound Keyword Mapping';
  if sig = 'AECH' then Result := 'Audio Effect Chain';
  if sig = 'SCCO' then Result := 'Scene Collection';
  if sig = 'AORC' then Result := 'Attraction Rule Component';
  if sig = 'LDMK' then Result := 'Location Marker';
  if sig = 'AMDL' then Result := 'Aim Model';
  if sig = 'LAYR' then Result := 'Layer';
  if sig = 'COEN' then Result := 'Collision Enabler';
  if sig = 'SPEL' then Result := 'Spell';
end;

procedure WriteRecordTypeSummary(data: TJsonObject);
var
  i: Integer;
  sig: String;
  countValue: String;
  displayName: String;
  item: TJsonObject;
begin
  if not Assigned(SignatureCounts) then
    Exit;

  for i := 0 to SignatureCounts.Count - 1 do begin
    sig := StoredField(SignatureCounts[i], 0);
    countValue := StoredField(SignatureCounts[i], 1);

    if sig <> '' then begin
      displayName := RecordSignatureDisplayName(sig);

      // Object form for quick reading:
      //   "Constructible Object (COBJ)": "65"
      data.O['recordTypes'].S[displayName + ' (' + sig + ')'] := countValue;

      // Array form for tools that prefer stable fields:
      item := data.A['recordTypeList'].AddObject;
      item.S['signature'] := sig;
      item.S['name'] := displayName;
      item.S['count'] := countValue;
    end;
  end;
end;

procedure BuildExportSummaryHeader;
var
  summary: TJsonObject;
begin
  summary := JSONData.O['exportSummary'];

  summary.S['schema'] := 'K2040_xEdit_JSON_Exporter_summary_v1_6';
  summary.S['sourcePlugin'] := SafeFileName(JSONElement);
  summary.S['exportMode'] := 'ALL';
  summary.S['exportedMainRecords'] := IntToStr(ExportedRecords);
  summary.S['exportedTES4Records'] := IntToStr(TES4ExportedRecordCount);
  summary.S['headerRecordCount'] := TES4HeaderRecordCount;
  summary.S['selectedRecordSignatures'] := SelectedSignaturesSuffixForOutput;

  if UseSelectedSignatureSuffixForOutput then
    summary.S['selectedRecordSignatureSuffixApplied'] := 'true'
  else
    summary.S['selectedRecordSignatureSuffixApplied'] := 'false';

  WriteRecordTypeSummary(summary);
end;

procedure WriteDetectedGroupsToValidation(data: TJsonObject);
var
  i: Integer;
begin
  if not Assigned(DetectedGroups) then
    Exit;

  for i := 0 to DetectedGroups.Count - 1 do
    data.A['detectedGroupNames'].AddObject.S['name'] := DetectedGroups[i];
end;

procedure BuildExportValidationReport;
var
  validation: TJsonObject;
  headerCount: Integer;
  nonTes4MainRecords: Integer;
  detectedGroupCount: Integer;
  calculatedTotal: Integer;
begin
  validation := JSONData.O['exportValidation'];

  validation.S['schema'] := 'K2040_xEdit_JSON_Exporter_validation_v1_6';
  validation.S['status'] := 'generated';
  validation.S['note'] := 'For Bethesda plugins, TES4 HEDR Number of Records commonly compares to non-TES4 main records plus GRUP containers.';
  validation.S['formula'] := 'calculatedHeaderComparableTotal = exportedMainRecords - exportedTES4Records + detectedGroupContainers';

  headerCount := StrToIntDef(TES4HeaderRecordCount, -1);
  detectedGroupCount := 0;

  if Assigned(DetectedGroups) then
    detectedGroupCount := DetectedGroups.Count;

  nonTes4MainRecords := ExportedRecords - TES4ExportedRecordCount;
  calculatedTotal := CalculatedHeaderComparableTotal;

  validation.S['headerRecordCount'] := TES4HeaderRecordCount;
  validation.S['exportedMainRecords'] := IntToStr(ExportedRecords);
  validation.S['exportedTES4Records'] := IntToStr(TES4ExportedRecordCount);
  validation.S['exportedNonTES4MainRecords'] := IntToStr(nonTes4MainRecords);
  validation.S['detectedGroupContainers'] := IntToStr(detectedGroupCount);
  validation.S['calculatedHeaderComparableTotal'] := IntToStr(calculatedTotal);

  if (headerCount >= 0) and (headerCount = calculatedTotal) then
    validation.S['matchesHeader'] := 'true'
  else
    validation.S['matchesHeader'] := 'false';

  WriteSignatureCountsToValidation(validation);
  WriteDetectedGroupsToValidation(validation);
end;

procedure MainToJSON(e: IInterface; data: TJsonObject);
begin
  AddRecordMeta(e, data);
  UpdateExportValidationForRecord(e);
  Progress := LogProgress(Progress);

  ChildrenToJSON(e, data);

  ExportedRecords := ExportedRecords + 1;
end;

procedure ElementToJSON(e: IInterface; data: TJsonObject);
begin
  if not Assigned(e) then
    Exit;

  Progress := LogProgress(Progress);

  if IsNativeGroupRecord(e) then begin
    Exit;
  end
  else if IsMain(e) then begin
    MainToJSON(e, data);
  end
  else if IsArray(e) then begin
    ArrayToJSON(e, data);
  end
  else if IsScalar(e) then begin
    ScalarToJSON(e, data);
  end
  else begin
    ObjectToJSON(e, data);
  end;
end;

function SanitizeJsonKey(value: String): String;
begin
  Result := value;

  if Result = '' then
    Result := 'unknown';

  Result := StringReplace(Result, ' ', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '.', '_', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  Result := StringReplace(Result, '[', '', [rfReplaceAll]);
  Result := StringReplace(Result, ']', '', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
end;


procedure AddSelectedSignature(sig: String);
begin
  if sig = '' then
    Exit;

  if not Assigned(SelectedSignatures) then
    Exit;

  if SelectedSignatures.IndexOf(sig) < 0 then
    SelectedSignatures.Add(sig);
end;

function SelectedSignaturesSuffix: String;
var
  i: Integer;
begin
  Result := '';

  if not Assigned(SelectedSignatures) then
    Exit;

  for i := 0 to SelectedSignatures.Count - 1 do begin
    if Result <> '' then
      Result := Result + '_';

    Result := Result + SelectedSignatures[i];
  end;
end;

function CalculatedHeaderComparableTotal: Integer;
var
  detectedGroupCount: Integer;
begin
  detectedGroupCount := 0;

  if Assigned(DetectedGroups) then
    detectedGroupCount := DetectedGroups.Count;

  Result := (ExportedRecords - TES4ExportedRecordCount) + detectedGroupCount;
end;

function IsCompletePluginExportByHeaderValidation: Boolean;
var
  headerCount: Integer;
begin
  Result := False;

  headerCount := StrToIntDef(TES4HeaderRecordCount, -1);

  if headerCount < 0 then
    Exit;

  if headerCount = CalculatedHeaderComparableTotal then
    Result := True;
end;

function UseSelectedSignatureSuffixForOutput: Boolean;
begin
  Result := False;

  if not SelectionExported then
    Exit;

  // If xEdit gave us an explicit file or group root, do not treat this as a
  // selected-record-only export.
  if Assigned(JSONElement) then begin
    if IsFile(JSONElement) then
      Exit;

    if IsNativeGroupRecord(JSONElement) then
      Exit;
  end;

  // When applying the script to a whole plugin, xEdit can still call Process()
  // for every contained main record. In that case the selected signature list
  // contains every record type in the plugin. If the export validates against
  // the TES4 header, keep the filename as <PluginName>.json.
  if IsCompletePluginExportByHeaderValidation then
    Exit;

  Result := True;
end;

function SelectedSignaturesSuffixForOutput: String;
begin
  Result := '';

  if UseSelectedSignatureSuffixForOutput then
    Result := SelectedSignaturesSuffix;
end;

function CurrentAutoOutputFileName: String;
var
  pluginName: String;
  sigSuffix: String;
begin
  pluginName := StripPluginExtension(AutoOutputFileName);

  if pluginName = '' then
    pluginName := 'UnknownPlugin';

  sigSuffix := SelectedSignaturesSuffixForOutput;

  if sigSuffix <> '' then
    Result := pluginName + '_' + sigSuffix + '.json'
  else
    Result := pluginName + '.json';
end;

function RecordExportKey(e: IInterface; index: Integer): String;
begin
  Result := SafeSignature(e) + '_' + SafeFixedFormID(e);

  if SafeEditorID(e) <> '' then
    Result := Result + '_' + SafeEditorID(e);

  if Result = '_' then
    Result := 'record_' + IntToStr(index);

  Result := SanitizeJsonKey(Result);
end;

function GroupExportKey(e: IInterface; index: Integer): String;
begin
  Result := 'GROUP_' + IntToStr(index) + '_' + SafeName(e);
  Result := SanitizeJsonKey(Result);
end;

function ElementExportKey(e: IInterface; index: Integer): String;
begin
  Result := 'ELEMENT_' + IntToStr(index) + '_' + SafeName(e);
  Result := SanitizeJsonKey(Result);
end;

procedure GroupToJSON(groupElement: IInterface; data: TJsonObject);
var
  index: Integer;
  child: IInterface;
  childKey: String;
begin
  data.S['_nodeKind'] := 'group';
  data.S['_xEditName'] := SafeName(groupElement);
  data.S['_xEditPath'] := SafePath(groupElement);
  data.S['_xEditFullPath'] := SafeFullPath(groupElement);
  data.S['_rawElementCount'] := IntToStr(ElementCount(groupElement));

  for index := 0 to ElementCount(groupElement) - 1 do begin
    child := ElementByIndex(groupElement, index);

    if not Assigned(child) then
      Continue;

    if IsNativeGroupRecord(child) then begin
      childKey := GroupExportKey(child, index);
      GroupToJSON(child, data.O['groups'].O[childKey]);
    end
    else if IsMain(child) then begin
      childKey := RecordExportKey(child, index);
      MainToJSON(child, data.O['records'].O[childKey]);
    end
    else begin
      childKey := ElementExportKey(child, index);
      ElementToJSON(child, data.O['elements'].O[childKey]);
    end;
  end;
end;

procedure FileToJSON(fileElement: IInterface; data: TJsonObject);
var
  fileRef: IInterface;
  index: Integer;
  child: IInterface;
  childKey: String;
begin
  fileRef := GetFile(fileElement);

  data.S['_rootType'] := 'fullPlugin';
  data.S['_fileName'] := GetFileName(fileRef);
  data.S['_exportMode'] := 'ALL_RECORDS_ALL_GROUPS';
  data.S['_note'] := 'Full decoded xEdit tree export.';

  for index := 0 to ElementCount(fileRef) - 1 do begin
    child := ElementByIndex(fileRef, index);

    if not Assigned(child) then
      Continue;

    if IsNativeGroupRecord(child) then begin
      childKey := GroupExportKey(child, index);
      GroupToJSON(child, data.O['groups'].O[childKey]);
    end
    else if IsMain(child) then begin
      childKey := RecordExportKey(child, index);
      MainToJSON(child, data.O['records'].O[childKey]);
    end
    else begin
      childKey := ElementExportKey(child, index);
      ElementToJSON(child, data.O['elements'].O[childKey]);
    end;
  end;
end;

procedure RootToJSON(e: IInterface; data: TJsonObject);
var
  rootRecord: IInterface;
begin
  if not Assigned(e) then begin
    AddMessage('No root element was captured.');
    Exit;
  end;

  if IsFile(e) then begin
    FileToJSON(e, data);
  end
  else if IsNativeGroupRecord(e) then begin
    data.S['_rootType'] := 'group';
    GroupToJSON(e, data.O['group']);
  end
  else if IsMain(e) then begin
    data.S['_rootType'] := 'record';
    MainToJSON(e, data.O['record']);
  end
  else begin
    try
      rootRecord := ContainingMainRecord(e);
      if Assigned(rootRecord) then begin
        data.S['_rootType'] := 'containingRecord';
        MainToJSON(rootRecord, data.O['record']);
      end
      else begin
        AddMessage('Selected element is not a file, group, or main record.');
        AddMessage('Try selecting the whole plugin, a group, or any main record.');
      end;
    except
      AddMessage('Could not resolve selected element to a supported record.');
    end;
  end;
end;

function StripPluginExtension(fileName: String): String;
begin
  Result := fileName;

  Result := StringReplace(Result, '.esp', '', [rfIgnoreCase]);
  Result := StringReplace(Result, '.esm', '', [rfIgnoreCase]);
  Result := StringReplace(Result, '.esl', '', [rfIgnoreCase]);
end;

function BuildAutoOutputFileName(e: IInterface): String;
var
  pluginName: String;
begin
  pluginName := '';

  try
    pluginName := GetFileName(GetFile(e));
  except
    pluginName := '';
  end;

  if pluginName = '' then
    pluginName := 'UnknownPlugin';

  // v1.4: keep automatic names short.
  // Full plugin/group export:
  //   PluginName.json
  // Selected record export:
  //   PluginName_OMOD_WEAP.json
  Result := StripPluginExtension(pluginName) + '.json';
end;

function HasAnyPathPart(filename: String): Boolean;
begin
  Result := False;
  if Pos('\', filename) > 0 then Result := True;
  if Pos('/', filename) > 0 then Result := True;
  if Pos(':', filename) > 0 then Result := True;
end;

function IsAbsolutePath(filename: String): Boolean;
begin
  Result := False;

  // Windows drive path, e.g. C:\Tools\out.json
  if Pos(':', filename) > 0 then
    Result := True;

  // Rooted path, e.g. \Temp\out.json or /tmp/out.json
  if Copy(filename, 1, 1) = '\' then
    Result := True;

  if Copy(filename, 1, 1) = '/' then
    Result := True;
end;

function EndsWithPathSeparator(filename: String): Boolean;
begin
  Result := False;

  if filename = '' then
    Exit;

  if Copy(filename, Length(filename), 1) = '\' then
    Result := True;

  if Copy(filename, Length(filename), 1) = '/' then
    Result := True;
end;

function EnsureJsonExtension(filename: String): String;
begin
  Result := filename;

  if ExtractFileExt(Result) = '' then
    Result := Result + '.json';
end;

function DefaultExportDirectory: String;
begin
  Result := ScriptsPath + 'K2040_xEdit_JSON_Exporter\Exports\';
end;

function DefaultOutputFileName: String;
begin
  Result := CurrentAutoOutputFileName;

  if Result = '' then
    Result := 'UnknownPlugin.json';
end;

function EnsureDirectoryExistsForFile(filename: String): String;
var
  dirName: String;
begin
  Result := filename;
  dirName := ExtractFilePath(Result);

  if dirName <> '' then begin
    if not DirectoryExists(dirName) then
      ForceDirectories(dirName);
  end;
end;

function EnsureExportPath(filename: String): String;
var
  outDir: String;
  typedValue: String;
begin
  typedValue := Trim(filename);
  outDir := DefaultExportDirectory;

  if typedValue = '' then
    typedValue := DefaultOutputFileName;

  // Directory-only input:
  //   MyExports\
  //   D:\Temp\
  // should become:
  //   MyExports\<PluginName>[_SIGNATURES].json
  //   D:\Temp\<PluginName>[_SIGNATURES].json
  if EndsWithPathSeparator(typedValue) then begin
    if IsAbsolutePath(typedValue) then
      Result := typedValue + DefaultOutputFileName
    else
      Result := ScriptsPath + typedValue + DefaultOutputFileName;

    EnsureDirectoryExistsForFile(Result);
    Exit;
  end;

  Result := EnsureJsonExtension(typedValue);

  // Absolute paths are respected exactly as typed.
  if IsAbsolutePath(Result) then begin
    EnsureDirectoryExistsForFile(Result);
    Exit;
  end;

  // Bare filenames go to the standard exporter folder.
  if not HasAnyPathPart(Result) then begin
    if not DirectoryExists(outDir) then
      ForceDirectories(outDir);

    Result := outDir + Result;
    Exit;
  end;

  // Relative paths with folders are anchored to ScriptsPath, not to an unknown
  // process working directory. Example:
  //   MyExports\test.json
  // becomes:
  //   <xEdit ScriptsPath>\MyExports\test.json
  Result := ScriptsPath + Result;
  EnsureDirectoryExistsForFile(Result);
end;

procedure ExportSelectedMainRecord(e: IInterface);
var
  key: String;
  recordsNode: TJsonObject;
begin
  if not IsMain(e) then
    Exit;

  key := RecordExportKey(e, 0);

  recordsNode := JSONData.O['root'].O['records'];

  // Avoid double-counting if xEdit calls Process twice for the same selected record.
  if recordsNode.O[key].S['_recordSignature'] <> '' then
    Exit;

  JSONData.O['root'].S['_rootType'] := 'selectedRecords';
  AddSelectedSignature(SafeSignature(e));
  MainToJSON(e, recordsNode.O[key]);

  SelectionExported := True;
  SelectedRecordCount := SelectedRecordCount + 1;
end;

function Initialize: Integer;
begin
  Result := 0;

  SetJDOLineBreak(#13#10);
  // SetJDOIndentChar(#9); // default tab
  // SetJDOUseUtcTime(True); // default True

  InitTypeHelpers;

  JSONFile := InputBox('K2040 xEdit JSON Exporter', 'File name to save to. Leave blank for automatic <PluginName>.json, or <PluginName>_SIGNATURES.json for selected records. Directory-only input also uses automatic filename:', '');

  JSONData := TJsonObject.Create;
  JSONData.O['exportSummary'];
  SignatureCounts := TStringList.Create;
  DetectedGroups := TStringList.Create;
  SelectedSignatures := TStringList.Create;

  AutoOutputFileName := '';
  JSONElement := nil;
  UICount := 1000;
  Progress := 0;
  ExportedRecords := 0;
  SelectionExported := False;
  SelectedRecordCount := 0;
  TES4HeaderRecordCount := '';
  TES4ExportedRecordCount := 0;

  AddMessage('K2040 xEdit JSON Exporter v1.6 started.');
  AddMessage('Export mode: ALL signatures / full xEdit tree');
end;

function Process(e: IInterface): Integer;
begin
  Result := 0;

  // For selected main records, export each one immediately so multi-record
  // selections are preserved. The final/highest element is still kept for
  // file/group/root fallback handling in Finalize().
  if IsMain(e) then
    ExportSelectedMainRecord(e)
  else
    JSONElement := e;

  if AutoOutputFileName = '' then begin
    try
      AutoOutputFileName := BuildAutoOutputFileName(e);
    except
      AutoOutputFileName := 'UnknownPlugin.json';
    end;
  end;
end;

function Finalize: Integer;
begin
  Result := 0;

  try
    JSONData.S['schema'] := 'K2040_xEdit_JSON_Exporter_v1_6';
    JSONData.S['description'] := 'Full raw xEdit tree export';
    JSONData.S['exporter'] := 'K2040_xEdit_JSON_Exporter_v1_6.pas';
    JSONData.S['exportMode'] := 'ALL';

    AddMessage('Marshalling: start');

    if SelectionExported then begin
      JSONData.O['root'].S['selectedRecordCount'] := IntToStr(SelectedRecordCount);

      // If xEdit also gave us a file or group as the final root element, include
      // the hierarchical view as fullTree while preserving the selected record set.
      if IsFile(JSONElement) then begin
        FileToJSON(JSONElement, JSONData.O['fullTree']);
      end
      else if IsNativeGroupRecord(JSONElement) then begin
        JSONData.O['fullTree'].S['_rootType'] := 'group';
        GroupToJSON(JSONElement, JSONData.O['fullTree'].O['group']);
      end;
    end
    else begin
      RootToJSON(JSONElement, JSONData.O['root']);
    end;

    JSONData.S['exportedRecordCount'] := IntToStr(ExportedRecords);

    BuildExportValidationReport;
    BuildExportSummaryHeader;

    if Trim(JSONFile) = '' then
      JSONFile := CurrentAutoOutputFileName;

    JSONFile := EnsureExportPath(JSONFile);
    JSONData.S['outputFile'] := JSONFile;
    JSONData.S['autoNamingPattern'] := '<PluginName>.json or <PluginName>_SIGNATURES.json for selected records';
    JSONData.SaveToFile(JSONFile, False, TEncoding.UTF8, True);

    AddMessage('Marshalling: done');
    AddMessage('Exported records: ' + IntToStr(ExportedRecords));
    AddMessage('Saved JSON to: ' + JSONFile);
  finally
    if Assigned(SignatureCounts) then
      SignatureCounts.Free;
    if Assigned(DetectedGroups) then
      DetectedGroups.Free;
    if Assigned(SelectedSignatures) then
      SelectedSignatures.Free;
    JSONData.Free;
  end;
end;

end.
