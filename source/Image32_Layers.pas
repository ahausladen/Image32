unit Image32_Layers;

(*******************************************************************************
* Author    :  Angus Johnson                                                   *
* Version   :  2.1                                                             *
* Date      :  12 March 2021                                                   *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2019-2021                                         *
* Purpose   :  Layer support for the Image32 library                           *
* License   :  http://www.boost.org/LICENSE_1_0.txt                            *
*******************************************************************************)

interface

{$I Image32.inc}

uses
  SysUtils, Classes, Math, Types,
  {$IFDEF XPLAT_GENERICS} Generics.Collections, {$ENDIF}
  Image32, Image32_Draw, Image32_Extra, Image32_Vector, Image32_Transform;

type
  TSizingStyle = (ssCorners, ssEdges, ssEdgesAndCorners);
  TButtonShape = Image32_Extra.TButtonShape;

  TLayer32 = class;
  TLayer32Class = class of TLayer32;
  TLayeredImage32 = class;
  TGroupLayer32 = class;

  TLayerHitTestEvent =
    function (layer: TLayer32; const pt: TPoint): Boolean of Object;

  TArrayOfPointer = array of Pointer;

  //THitTestRec is used for hit-testing (see TLayeredImage32.GetLayerAt).
  THitTestRec = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    PtrPixels : TArrayOfPointer;
    width  : integer;
    height : integer;
    function IsEmpty: Boolean;
    procedure Init(ownerLayer: TLayer32);
    procedure Clear;
  end;

  TLayerNotifyImage32 = class(TImage32)
  protected
    fOwnerLayer: TLayer32;
    procedure Changed; override;
  public
    constructor Create(owner: TLayer32);
  end;

{$IFDEF ZEROBASEDSTR}
  {$ZEROBASEDSTRINGS OFF}
{$ENDIF}

  TLayer32 = class
  private
    fImageLayer     : TLayeredImage32;
    fGroupOwner     : TGroupLayer32;
    fLeft           : integer;
    fTop            : integer;
    fImage          : TImage32;
    fName           : string;
    fIndex          : integer;
    fVisible        : Boolean;
    fOpacity        : Byte;
    fCursorId       : integer;
    fTag            : Cardinal;
    fOldWidth       : integer;
    fOldHeight      : integer;
    fHitTestRec     : THitTestRec;
    fFullRefreshPending : boolean;
    function   GetMidPoint: TPointD;
    procedure  SetVisible(value: Boolean);
    function   GetHeight: integer;
    function   GetWidth: integer;
    procedure  SetOpacity(value: Byte);
  protected
    procedure  BeginUpdate; virtual;
    procedure  EndUpdate;   virtual;
    function   CanUpdate: Boolean;
    function   GetBounds: TRect;
    procedure  ImageChanged(Sender: TImage32); virtual;
    property   HitTestRec : THitTestRec read fHitTestRec write fHitTestRec;
    property   OldWidth   : integer read fOldWidth;
    property   OldHeight  : integer read fOldHeight;
  public
    constructor Create(groupOwner: TGroupLayer32;
      const name: string = ''); virtual;
    destructor Destroy; override;
    procedure  SetSize(width, height: integer);

    function   BringForwardOne: Boolean;
    function   SendBackOne: Boolean;
    function   BringToFront: Boolean;
    function   SendToBack: Boolean;

    procedure  PositionAt(const pt: TPoint); overload;
    procedure  PositionAt(x, y: integer); overload;
    procedure  PositionCenteredAt(X, Y: integer); overload;
    procedure  PositionCenteredAt(const pt: TPoint); overload;
    procedure  PositionCenteredAt(const pt: TPointD); overload;
    procedure  SetBounds(const newBounds: TRect); virtual;
    procedure  Offset(dx, dy: integer); virtual;

    property   Bounds: TRect read GetBounds;
    property   CursorId: integer read fCursorId write fCursorId;
    property   GroupOwner: TGroupLayer32 read fGroupOwner;
    property   Height: integer read GetHeight;
    property   Image: TImage32 read fImage;
    property   Index: integer read fIndex;
    property   Left: integer read fLeft;
    property   MidPoint: TPointD read GetMidPoint;
    property   Name: string read fName write fName;
    property   Opacity: Byte read fOpacity write SetOpacity;
    property   RootOwner: TLayeredImage32 read fImageLayer;
    property   Top: integer read fTop;
    property   Visible: Boolean read fVisible write SetVisible;
    property   Width: integer read GetWidth;
    property   Tag: Cardinal read fTag write fTag;
  end;

  TGroupType = (gtNone, gtFinal, gtDesign, gtMixed);

  TGroupLayer32 = class(TLayer32)
  private
{$IFDEF XPLAT_GENERICS}
    fChilds                : TList<TLayer32>;
{$ELSE}
    fChilds                : TList;
{$ENDIF}
    fGroupType             : TGroupType;
    fLocalInvalidRect      : TRect;
    fUpdateCount           : Integer; //see beginUpdate/EndUpdate
    fRefreshPending        : Boolean;
    fOnMerge               : TNotifyEvent;
    function  GetChildCount: integer;
    function  GetChild(index: integer): TLayer32;
    function  FindLayerNamed(const name: string): TLayer32; virtual;
    procedure ReindexChildsFrom(startIdx: Integer);
    procedure UpdateGroupType;
  protected
    procedure Merge(hideDesigners: Boolean; const invalidRect: TRect);
    function  GetLayerAt(const pt: TPoint; ignoreDesigners: Boolean): TLayer32;
    procedure InternalDeleteChild(index: integer; fromChild: Boolean);
    procedure BeginUpdate; override;
    procedure EndUpdate;   override;
    procedure ForceRefresh;
    function   GetChildrenBounds(excludeDesigners: Boolean): TRect;
    procedure MergeInvalidatedRects(mergeAll, hideDesigners: Boolean;
      var invalidRects: TRect);
    //DoOnMerge: for last minute sizing & painting (eg see Image32_SmoothPath)
    procedure  DoOnMerge; virtual;
  public
    constructor Create(groupOwner: TGroupLayer32; const name: string = ''); override;
    destructor Destroy; override;
    function   AddChild(layerClass: TLayer32Class; const name: string = ''): TLayer32;
    function   InsertChild(layerClass: TLayer32Class; index: integer; const name: string = ''): TLayer32;
    procedure  DeleteChild(index: integer);
    procedure  Invalidate(rec: TRect);

    procedure  SetBounds(const newBounds: TRect); override;
    procedure  Offset(dx, dy: integer); override;
    procedure  ClearChildren;
    property   ChildCount: integer read GetChildCount;
    property   Child[index: integer]: TLayer32 read GetChild; default;
    property   OnMerge: TNotifyEvent read fOnMerge write fOnMerge;
  end;

  THitTestLayer32 = class(TLayer32)
  public
    function GetPathsFromHitTestMask: TPathsD;
  end;

  TVectorLayer32 = class(THitTestLayer32)
  private
    fPaths      : TPathsD;
    fAngle      : double;
    fMargin     : integer;
    fPivotPt    : TPointD;
    fAutoPivot  : Boolean;
    fOnDraw     : TNotifyEvent;
    procedure SetAngle(newAngle: double);
    procedure SetMargin(new: integer);
    procedure RepositionAndDraw;
    procedure SetPaths(const newPaths: TPathsD);
    procedure SetPivotPt(const pivot: TPointD);
    procedure SetAutoPivot(val: Boolean);
  public
    constructor Create(groupOwner: TGroupLayer32; const name: string = ''); override;
    procedure SetBounds(const newBounds: TRect); override;
    procedure Offset(dx,dy: integer); override;
    procedure Rotate(const pivot: TPointD; angleDelta: double); overload;
    procedure Rotate(angleDelta: double); overload;
    procedure ResetAngle;
    procedure UpdateHitTestMask(const vectorRegions: TPathsD;
      fillRule: TFillRule); virtual;
    property  Paths: TPathsD read fPaths write SetPaths;
    property  Angle: double read fAngle write SetAngle;
    property  Margin: integer read fMargin write SetMargin;
    property  PivotPt: TPointD read fPivotPt write SetPivotPt;
    property  AutoCenterPivot: Boolean read fAutoPivot write SetAutoPivot;
    property  OnDraw: TNotifyEvent read fOnDraw write fOnDraw;
  end;

  TRasterLayer32 = class(THitTestLayer32)
  private
    fMasterImg    : TImage32;
    //a matrix allows combining any number of sizing & rotating
    //operations into a single transformation
    fMatrix       : TMatrixD;
    fRotating     : Boolean;
    fAngle        : double;
    fSavedSize    : TSize;
    fAutoHitTest  : Boolean;
    procedure SetAngle(newAngle: double);
    procedure DoAutoHitTest;
    procedure DoRotateCheck;
    procedure DoScaleCheck;
  protected
    procedure  ImageChanged(Sender: TImage32); override;
  public
    constructor Create(groupOwner: TGroupLayer32; const name: string = ''); override;
    destructor  Destroy; override;
    procedure UpdateHitTestMaskOpaque;
    procedure UpdateHitTestMaskTransparent; overload; virtual;
    procedure UpdateHitTestMaskTransparent(compareFunc: TCompareFunction;
      referenceColor: TColor32; tolerance: integer); overload; virtual;

    procedure SetBounds(const newBounds: TRect); override;
    procedure Rotate(angleDelta: double);

    property  Angle: double read fAngle write SetAngle;
    property  AutoSetHitTestMask: Boolean read fAutoHitTest write fAutoHitTest;
    property  MasterImage: TImage32 read fMasterImg;
  end;

  TSizingGroupLayer32 = class(TGroupLayer32)
  private
    fSizingStyle: TSizingStyle;
  public
    property SizingStyle: TSizingStyle read fSizingStyle write fSizingStyle;
  end;

  TRotatingGroupLayer32 = class(TGroupLayer32)
  private
    fZeroOffset: double;
    function GetDistance: double;
    function GetRotCur: integer;
    procedure SetRotCur(curId: integer);
    function GetAngle: double;
    function GetPivot: TPointD;
  public
    property Angle: double read GetAngle;
    property Pivot: TPointD read GetPivot;
    property CursorId: integer read GetRotCur write SetRotCur;
    property DistBetweenButtons: double read GetDistance;
  end;

  TButtonDesignerLayer32 = class;
  TButtonDesignerLayer32Class = class of TButtonDesignerLayer32;

  TButtonGroupLayer32 = class(TGroupLayer32)
  private
    fBtnSize: integer;
    fBtnShape: TButtonShape;
    fBtnColor: TColor32;
    fBbtnLayerClass: TButtonDesignerLayer32Class;
  public
    function AddButton(const pt: TPointD): TButtonDesignerLayer32;
    function InsertButton(const pt: TPointD; btnIdx: integer): TButtonDesignerLayer32;
  end;

  TDesignerLayer32 = class(THitTestLayer32)
  public
    procedure UpdateHitTestMask(const vectorRegions: TPathsD;
      fillRule: TFillRule); virtual;
  end;

  TButtonDesignerLayer32 = class(TDesignerLayer32)
  private
    fSize     : integer;
    fColor    : TColor32;
    fShape    : TButtonShape;
    fButtonOutline: TPathD;
  protected
    procedure Draw; virtual;
    property Size  : integer read fSize write fSize;
    property Color : TColor32 read fColor write fColor;
    property Shape : TButtonShape read fShape write fShape;
    procedure SetButtonAttributes(const shape: TButtonShape;
      size: integer; color: TColor32);
  public
    property ButtonOutline: TPathD read fButtonOutline write fButtonOutline;
  end;

  TLayeredImage32 = class
  private
    fRoot      : TGroupLayer32;
    fBackColor      : TColor32;
    fPreviousHideDesignerState: Boolean;
    fBounds         : TRect;
    function  GetRootLayersCount: integer;
    function  GetLayer(index: integer): TLayer32;
    function  GetImage: TImage32;
    function  GetHeight: integer;
    procedure SetHeight(value: integer);
    function  GetWidth: integer;
    procedure SetWidth(value: integer);
    procedure SetBackColor(color: TColor32);
    function  GetMidPoint: TPointD;
  public
    constructor Create(Width: integer = 0; Height: integer =0); virtual;
    destructor Destroy; override;
    procedure SetSize(width, height: integer);
    procedure Clear;
    procedure Invalidate;
    function  AddLayer(layerClass: TLayer32Class = nil;
      group: TGroupLayer32 = nil; const name: string = ''): TLayer32;
    function  InsertLayer(layerClass: TLayer32Class; group: TGroupLayer32;
      index: integer; const name: string = ''): TLayer32;
    procedure DeleteLayer(layer: TLayer32); overload;
    procedure DeleteLayer(layerIndex: integer;
      groupOwner: TGroupLayer32 = nil); overload;
    function  FindLayerNamed(const name: string): TLayer32;
    function  GetLayerAt(const pt: TPoint; ignoreDesigners: Boolean = false): TLayer32;
    function  GetMergedImage(hideDesigners: Boolean = false): TImage32; overload;
    function  GetMergedImage(hideDesigners: Boolean;
      out updateRect: TRect): TImage32; overload;

    property BackgroundColor: TColor32 read fBackColor write SetBackColor;
    property Bounds: TRect read fBounds;
    property Count: integer read GetRootLayersCount;
    property Height: integer read GetHeight write SetHeight;
    property Image: TImage32 read GetImage;
    property Layer[index: integer]: TLayer32 read GetLayer; default;
    property MidPoint: TPointD read GetMidPoint;
    property Root: TGroupLayer32 read fRoot;
    property Width: integer read GetWidth write SetWidth;
  end;

//CreateSizingButtonGroup: the buttonLayerClass parameter allows the
//user to define their own buttonLayerClass with a custom Draw method.
function CreateSizingButtonGroup(targetLayer: TLayer32;
  sizingStyle: TSizingStyle; buttonShape: TButtonShape;
  buttonSize: integer; buttonColor: TColor32;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TSizingGroupLayer32;

function CreateRotatingButtonGroup(targetLayer: TLayer32;
  const pivot: TPointD; buttonSize: integer = 0;
  centerButtonColor: TColor32 = clWhite32;
  movingButtonColor: TColor32 = clBlue32;
  startingAngle: double = 0; startingZeroOffset: double = 0;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TRotatingGroupLayer32; overload;

function CreateRotatingButtonGroup(targetLayer: TLayer32;
  buttonSize: integer = 0;
  centerButtonColor: TColor32 = clWhite32;
  movingButtonColor: TColor32 = clBlue32;
  startingAngle: double = 0; startingZeroOffset: double = 0;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TRotatingGroupLayer32; overload;

function CreateButtonGroup(groupOwner: TGroupLayer32;
  const buttonPts: TPathD; buttonShape: TButtonShape;
  buttonSize: integer; buttonColor: TColor32;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TButtonGroupLayer32;

function UpdateSizingButtonGroup(movedButton: TLayer32): TRect;

//UpdateRotatingButtonGroup: returns rotation angle
function UpdateRotatingButtonGroup(rotateButton: TLayer32): double;

var
  DefaultButtonSize: integer;
  dashes: TArrayOfInteger;

const
  crDefault   =   0;
  crArrow     =  -2;
  crSizeNESW  =  -6;
  crSizeNS    =  -7;
  crSizeNWSE  =  -8;
  crSizeWE    =  -9;
  crHandPoint = -21;
  crSizeAll   = -22;

implementation

resourcestring
  rsButton                 = 'Button';
  rsDesign                 = 'Design';
  rsSizingButtonGroup      = 'SizingButtonGroup';
  rsRotatingButtonGroup    = 'RotatingButtonGroup';
  rsDesignButtonGroup      = 'DesignAndButtonGroup';
  rsChildIndexRangeError   = 'TGroupLayer32 - child index error';
  rsCreateButtonGroupError = 'CreateButtonGroup - invalid target layer';
  rsUpdateRotateGroupError = 'UpdateRotateGroup - invalid group';


//------------------------------------------------------------------------------
// TLayerNotifyImage32
//------------------------------------------------------------------------------

constructor TLayerNotifyImage32.Create(owner: TLayer32);
begin
  inherited Create;
  fOwnerLayer := owner;
end;
//------------------------------------------------------------------------------

procedure TLayerNotifyImage32.Changed;
begin
  if (Self.UpdateCount = 0) and Assigned(fOwnerLayer) then
    fOwnerLayer.ImageChanged(Self);
  inherited;
end;

//------------------------------------------------------------------------------
// THitTestRec
//------------------------------------------------------------------------------

function THitTestRec.IsEmpty: Boolean;
begin
  Result := (width <= 0) or (height <= 0);
end;
//------------------------------------------------------------------------------

procedure THitTestRec.Init(ownerLayer: TLayer32);
begin
  width := ownerLayer.width;
  height := ownerLayer.height;
  PtrPixels := nil;
  if not IsEmpty then
    SetLength(PtrPixels, width * height);
end;
//------------------------------------------------------------------------------

procedure THitTestRec.Clear;
begin
  width := 0; height := 0; PtrPixels := nil;
end;

//------------------------------------------------------------------------------
// TPointerRenderer: renders both 32 & 64bits pointer 'pixels' for hit-testing
//------------------------------------------------------------------------------

type

  TPointerRenderer = class(TCustomRenderer)
  private
    fObjPointer: Pointer;
  protected
    procedure RenderProc(x1, x2, y: integer; alpha: PByte); override;
  public
    constructor Create(objectPtr: Pointer);
  end;

procedure TPointerRenderer.RenderProc(x1, x2, y: integer; alpha: PByte);
var
  i: integer;
  dst: PPointer;
begin
  dst := GetDstPixel(x1,y);
  for i := x1 to x2 do
  begin
    if Byte(alpha^) > 127 then dst^ := fObjPointer;
    inc(PByte(dst), PixelSize); inc(alpha);
  end;
end;
//------------------------------------------------------------------------------

constructor TPointerRenderer.Create(objectPtr: Pointer);
begin
  fObjPointer := objectPtr;
end;

//------------------------------------------------------------------------------
// THitTestRec helper functions
//------------------------------------------------------------------------------

procedure UpdateHitTestMaskUsingPath(layer: THitTestLayer32;
  const paths: TPathsD; fillRule: TFillRule);
var
  monoRenderer: TPointerRenderer;
begin
  monoRenderer := TPointerRenderer.Create(layer);
  try
    with layer.HitTestRec do
    begin
      if IsEmpty then Exit;
      monoRenderer.Initialize(@PtrPixels[0], width, height, sizeOf(Pointer));
      Rasterize(paths, Rect(0,0,width,height), fillRule, monoRenderer);
    end;
  finally
    monoRenderer.Free;
  end;
end;
//------------------------------------------------------------------------------

//Creates a pointer hit-test mask using the supplied image and compareFunc.
procedure UpdateHitTestMaskUsingImage(var htr: THitTestRec;
  objPtr: Pointer; img: TImage32; compareFunc: TCompareFunction;
  referenceColor: TColor32; tolerance: integer);
var
  i: integer;
  pc: PColor32;
  pp: PPointer;
begin
  with img do
  begin
    htr.width := Width;
    htr.height := Height;
    htr.PtrPixels := nil;
    if IsEmpty then Exit;
    SetLength(htr.PtrPixels, Width * Height);
  end;

  pc := img.PixelBase;
  pp := @htr.PtrPixels[0];
  for i := 0 to high(htr.PtrPixels) do
  begin
    if compareFunc(referenceColor, pc^, tolerance) then pp^ := objPtr;
    inc(pc); inc(pp);
  end;
end;

//------------------------------------------------------------------------------
// TLayer32 class
//------------------------------------------------------------------------------

constructor TLayer32.Create(groupOwner: TGroupLayer32; const name: string);
begin
  fGroupOwner := groupOwner;
  if assigned(groupOwner) then fImageLayer := groupOwner.fImageLayer;
  fImage      := TLayerNotifyImage32.Create(self);
  fName       := name;
  fVisible    := True;
  fOpacity    := 255;
  CursorId    := crDefault;
end;
//------------------------------------------------------------------------------

destructor TLayer32.Destroy;
begin
  fImage.Free;
  fVisible := false;
  if Assigned(fGroupOwner) then
    fGroupOwner.InternalDeleteChild(Index, true);
end;
//------------------------------------------------------------------------------

procedure TLayer32.BeginUpdate;
begin
  if Assigned(fGroupOwner) then
    with fGroupOwner do
    begin
      if (fUpdateCount = 0) and not self.fFullRefreshPending then
        Invalidate(self.Bounds);
      Inc(fUpdateCount);
    end;
end;
//------------------------------------------------------------------------------

procedure TLayer32.EndUpdate;
begin
  if Assigned(fGroupOwner) then
    with fGroupOwner do
    begin
      Dec(fUpdateCount);
      if (fUpdateCount <> 0) then Exit;
      self.fFullRefreshPending := true;
      fRefreshPending := true;
    end;
end;
//------------------------------------------------------------------------------

function TLayer32.CanUpdate: Boolean;
begin
  Result := not assigned(fGroupOwner) or (fGroupOwner.fUpdateCount = 0);
end;
//------------------------------------------------------------------------------

procedure TLayer32.ImageChanged(Sender: TImage32);
begin
  if (Self is TGroupLayer32) or not CanUpdate then Exit;
  if not fFullRefreshPending and CanUpdate then
    //invalidate the maximum 'dirty' area
    GroupOwner.Invalidate(RectWH(fLeft, fTop,
      Max(Width, fOldWidth), Max(Height, fOldHeight)));
  fOldWidth := Width;
  fOldHeight := Height;
  HitTestRec.Clear;
end;
//------------------------------------------------------------------------------

procedure TLayer32.SetSize(width, height: integer);
begin
  if (width = Image.Width) and (height = Image.Height) then Exit;
  BeginUpdate;
  try
    Image.SetSize(width, height);
    fHitTestRec.Clear;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function TLayer32.GetHeight: integer;
begin
  Result := Image.Height;
end;
//------------------------------------------------------------------------------

function TLayer32.GetWidth: integer;
begin
  Result := Image.Width;
end;
//------------------------------------------------------------------------------

procedure  TLayer32.SetBounds(const newBounds: TRect);
begin
  BeginUpdate;
  try
    fLeft := newBounds.Left;
    fTop := newBounds.Top;
    Image.SetSize(RectWidth(newBounds),RectHeight(newBounds));
    fHitTestRec.Clear;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function TLayer32.GetBounds: TRect;
begin
  Result := Rect(fLeft, fTop, fLeft + fImage.Width, fTop + fImage.Height)
end;
//------------------------------------------------------------------------------

function TLayer32.GetMidPoint: TPointD;
begin
  Result := Image32_Vector.MidPoint(RectD(Bounds));
end;
//------------------------------------------------------------------------------

procedure TLayer32.PositionAt(const pt: TPoint);
begin
  if (fLeft = pt.X) and (fTop = pt.Y) then Exit;

  BeginUpdate;
  try
    fLeft := pt.X; fTop := pt.Y;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TLayer32.PositionAt(x, y: integer);
begin
  PositionAt(Types.Point(x, y));
end;
//------------------------------------------------------------------------------

procedure TLayer32.PositionCenteredAt(X, Y: integer);
var
  pt2: TPoint;
begin
  pt2.X := X - Image.Width div 2;
  pt2.Y := Y - Image.Height div 2;
  PositionAt(pt2);
end;
//------------------------------------------------------------------------------

procedure TLayer32.PositionCenteredAt(const pt: TPoint);
var
  pt2: TPoint;
begin
  pt2.X := pt.X - Image.Width div 2;
  pt2.Y := pt.Y - Image.Height div 2;
  PositionAt(pt2);
end;
//------------------------------------------------------------------------------

procedure TLayer32.PositionCenteredAt(const pt: TPointD);
var
  pt2: TPoint;
begin
  pt2.X := Round(pt.X - Image.Width * 0.5);
  pt2.Y := Round(pt.Y - Image.Height * 0.5);
  PositionAt(pt2);
end;
//------------------------------------------------------------------------------

procedure TLayer32.Offset(dx, dy: integer);
begin
  PositionAt(Left + dx, Top + dy);
end;
//------------------------------------------------------------------------------

procedure TLayer32.SetVisible(value: Boolean);
begin
  if (value = fVisible) then Exit;
  fVisible := value;
  if Assigned(fGroupOwner) then fGroupOwner.Invalidate(Bounds);
end;
//------------------------------------------------------------------------------

procedure TLayer32.SetOpacity(value: Byte);
begin
  if value = fOpacity then Exit;
  fOpacity := value;
  if Assigned(fGroupOwner) then GroupOwner.Invalidate(Bounds);
end;
//------------------------------------------------------------------------------

function TLayer32.BringForwardOne: Boolean;
begin
  Result := assigned(fGroupOwner) and (index < fGroupOwner.ChildCount -1);
  if not Result then Exit;
  fGroupOwner.fChilds.Move(index, index +1);
  fGroupOwner.ReindexChildsFrom(index);
  fGroupOwner.Invalidate(Bounds);
end;
//------------------------------------------------------------------------------

function TLayer32.SendBackOne: Boolean;
begin
  Result := assigned(fGroupOwner) and (index > 0);
  if not Result then Exit;
  fGroupOwner.fChilds.Move(index, index -1);
  fGroupOwner.ReindexChildsFrom(index -1);
  fGroupOwner.Invalidate(Bounds);
end;
//------------------------------------------------------------------------------

function TLayer32.BringToFront: Boolean;
begin
  Result := index < fGroupOwner.ChildCount -1;
  if not Result then Exit;
  fGroupOwner.fChilds.Move(index, fGroupOwner.ChildCount -1);
  fGroupOwner.ReindexChildsFrom(index);
  fGroupOwner.Invalidate(Bounds);
end;
//------------------------------------------------------------------------------

function TLayer32.SendToBack: Boolean;
begin
  Result := assigned(fGroupOwner) and (index > 0);
  if not Result then Exit;
  fGroupOwner.fChilds.Move(index, 0);
  fGroupOwner.ReindexChildsFrom(0);
  fGroupOwner.Invalidate(Bounds);
end;

//------------------------------------------------------------------------------
// TGroupLayer32 class
//------------------------------------------------------------------------------

constructor TGroupLayer32.Create(groupOwner: TGroupLayer32; const name: string);
begin
  inherited;
{$IFDEF XPLAT_GENERICS}
  fChilds := TList<TLayer32>.Create;
{$ELSE}
  fChilds := TList.Create;
{$ENDIF}

  fGroupType := gtNone;
end;
//------------------------------------------------------------------------------

destructor TGroupLayer32.Destroy;
begin
  ClearChildren;
  fChilds.Free;
  //pass this group's invalid rect on to its owner group
  if assigned(fGroupOwner) then
      fGroupOwner.Invalidate(fLocalInvalidRect);
  inherited;
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.BeginUpdate;
begin
  // we need to mark invalid the regions that WERE covered,
  // unless it this region has already been marked invalid.
  if (fUpdateCount = 0) then
      Invalidate(GetChildrenBounds(false));
  Inc(fUpdateCount);
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.EndUpdate;
begin
  Dec(fUpdateCount);
  //now mark this whole group's region as invalid ...
  if (fUpdateCount = 0) then
    Invalidate(GetChildrenBounds(false));
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.ForceRefresh;
begin
  fRefreshPending := true;
end;
//------------------------------------------------------------------------------

function  TGroupLayer32.GetChildrenBounds(excludeDesigners: Boolean): TRect;

  function GetChildBounds(child: TLayer32): TRect;
  begin
    if child is TGroupLayer32 then
      result := TGroupLayer32(child).GetChildrenBounds(excludeDesigners)
    else if child.Visible and not child.Image.IsEmpty and
      not (excludeDesigners and (child is TDesignerLayer32)) then
      Result := child.Bounds
    else
      Result := NullRect;
  end;

var
  i: integer;
begin
  Result := NullRect;
  if not Visible or (ChildCount = 0) then Exit;
  for i := 0 to ChildCount -1 do
    Result := Image32_Vector.UnionRect(Result, GetChildBounds(Child[i]));
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.Invalidate(rec: TRect);
begin
  if (fUpdateCount <> 0) or IsEmptyRect(rec) then Exit;
  fLocalInvalidRect :=
    Image32_Vector.UnionRect(fLocalInvalidRect, rec);
end;
//------------------------------------------------------------------------------

function TGroupLayer32.GetChildCount: integer;
begin
  Result := fChilds.Count;
end;
//------------------------------------------------------------------------------

function TGroupLayer32.GetChild(index: integer): TLayer32;
begin
  if (index < 0) or (index >= fChilds.Count) then
    raise Exception.Create(rsChildIndexRangeError);
  Result := TLayer32(fChilds[index]);
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.ClearChildren;
var
  i: integer;
begin
  BeginUpdate;
  try
    for i := fChilds.Count -1 downto 0 do
      TLayer32(fChilds[i]).Free;
    fChilds.Clear;
    fGroupType := gtNone;
    SetBounds(NullRect);
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function   TGroupLayer32.AddChild(layerClass: TLayer32Class;
  const name: string = ''): TLayer32;
begin
  Result := InsertChild(layerClass, MaxInt, name);
end;
//------------------------------------------------------------------------------

function   TGroupLayer32.InsertChild(layerClass: TLayer32Class;
  index: integer; const name: string = ''): TLayer32;
begin
  Result := layerClass.Create(self, name);
  if index >= ChildCount then
  begin
    Result.fIndex := ChildCount;
    fChilds.Add(Result);
  end else
  begin
    Result.fIndex := index;
    fChilds.Insert(index, Result);
    ReindexChildsFrom(index +1);
  end;

  //update Group's type
  if (Result is TDesignerLayer32) then
  begin
    if fGroupType = gtNone then
      fGroupType := gtDesign
    else if fGroupType = gtFinal then
      fGroupType := gtMixed;
  end else
  begin
    if fGroupType = gtNone then
      fGroupType := gtFinal
    else if fGroupType = gtDesign then
      fGroupType := gtMixed;
  end;
end;
//------------------------------------------------------------------------------

procedure  TGroupLayer32.InternalDeleteChild(index: integer; fromChild: Boolean);
var
  child: TLayer32;
begin
  if (index < 0) or (index >= fChilds.Count) then
    raise Exception.Create(rsChildIndexRangeError);

  child := TLayer32(fChilds[index]);
  if child.Visible then
    Invalidate(child.Bounds);

  fChilds.Delete(index);
  if not fromChild then
  begin
    child.fGroupOwner := nil; //avoids recursion :)
    child.Free;
  end;
  if index < ChildCount then
    ReindexChildsFrom(index);

  if CanUpdate then UpdateGroupType;
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.DeleteChild(index: integer);
begin
  InternalDeleteChild(index, false);
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.UpdateGroupType;

  function GetChildGroupType(child: TLayer32): TGroupType;
  begin
    if (child is TGroupLayer32) then
      Result := TGroupLayer32(child).fGroupType
    else if (child is TDesignerLayer32) then
      Result := gtDesign
    else
      Result := gtFinal;
  end;

var
  i: integer;
  cgt: TGroupType;
begin
  fGroupType := gtNone;
  for i := 0 to ChildCount -1 do
  begin
    cgt := GetChildGroupType(Child[i]);
    if cgt = gtNone then Continue
    else if fGroupType = gtNone then fGroupType := cgt
    else if cgt <> fGroupType then
    begin
      fGroupType := gtMixed;
      break;
    end;
  end;
end;
//------------------------------------------------------------------------------

procedure  TGroupLayer32.SetBounds(const newBounds: TRect);
begin
  //this method overrride bypasses the overhead of BeginUpdate/EndUpdate
  fLeft := newBounds.Left;
  fTop := newBounds.Top;
  Image.SetSize(RectWidth(newBounds),RectHeight(newBounds));
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.Offset(dx, dy: integer);
var
  i: integer;
begin
  if (dx = 0) and (dy = 0) then Exit;
  BeginUpdate;
  try
    for i := 0 to ChildCount -1 do
      Child[i].Offset(dx, dy);
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.DoOnMerge;
begin
  if Assigned(fOnMerge) then fOnMerge(self);
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.MergeInvalidatedRects(
  mergeAll, hideDesigners: Boolean; var invalidRects: TRect);
var
  i: integer;
begin

  DoOnMerge;

  //recursively apply this method ...
  for i := 0 to ChildCount -1 do
    if (Child[i] is TGroupLayer32) then
      with TGroupLayer32(Child[i]) do
        MergeInvalidatedRects(mergeAll, hideDesigners, invalidRects);

  SetBounds(GetChildrenBounds(hideDesigners));

  if mergeAll or
    (not fRefreshPending and IsEmptyRect(fLocalInvalidRect)) then
      Exit;

  invalidRects := Image32_Vector.UnionRect(invalidRects, fLocalInvalidRect);
  if fRefreshPending then
    for i := 0 to ChildCount -1 do
      if not (Child[i] is TGroupLayer32) and
        Child[i].fFullRefreshPending then
        begin
          invalidRects :=
            Image32_Vector.UnionRect(invalidRects, Child[i].GetBounds);
          Child[i].fFullRefreshPending := false;
        end;

  fLocalInvalidRect := NullRect;
  fRefreshPending := false;

end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.Merge(hideDesigners: Boolean; const invalidRect: TRect);
var
  i: integer;
  tmp: TImage32;
  srcRect, dstRect: TRect;
begin
  if not Visible or (Opacity < 2) or Image.IsEmpty or
    (hideDesigners and (fGroupType = gtDesign)) then Exit;

  for i := 0 to ChildCount -1 do
    with Child[i] do
    begin
      if not Visible or
        (hideDesigners and (Child[i] is TDesignerLayer32)) then
          Continue;

      srcRect := Image32_Vector.IntersectRect(GetBounds, invalidRect);
      if IsEmptyRect(srcRect) then Continue;

      if (Child[i] is TGroupLayer32) then
        with TGroupLayer32(Child[i]) do
          Merge(hideDesigners, invalidRect);

      //make srcRect relative to image
      Image32_Vector.OffsetRect(srcRect, -Left, -Top);
      //make dstRect relative to groupLayer
      dstRect := srcRect;
      Image32_Vector.OffsetRect(dstRect, Left -self.Left, Top -self.Top);

      if fOpacity < 254 then //reduce layer opacity
      begin
        tmp := TImage32.Create(Image);
        try
          tmp.ScaleAlpha(fOpacity/255);
          self.Image.CopyBlend(tmp, srcRect, dstRect, BlendToAlpha);
        finally
          tmp.Free;
        end;
      end else
        self.Image.CopyBlend(Image, srcRect, dstRect, BlendToAlpha);
    end;
end;
//------------------------------------------------------------------------------

function TGroupLayer32.GetLayerAt(const pt: TPoint;
  ignoreDesigners: Boolean): TLayer32;
var
  i: integer;
begin
  Result := nil;
  for i := ChildCount -1 downto 0 do
  begin
    if Child[i] is TGroupLayer32 then
      Result := TGroupLayer32(Child[i]).GetLayerAt(pt, ignoreDesigners)
    else
    begin
      with Child[i] do
        if not Visible or
          (ignoreDesigners and (Child[i] is TDesignerLayer32)) or
          fHitTestRec.IsEmpty or not PtInRect(Bounds, pt) then
            Continue
        else
          Result := fHitTestRec.PtrPixels[
            fHitTestRec.width * (pt.Y - Top) + (pt.X  -Left)];
    end;
    if Assigned(Result) then Break;
  end;
end;
//------------------------------------------------------------------------------

procedure TGroupLayer32.ReindexChildsFrom(startIdx: Integer);
var
  i: integer;
begin
  for i := startIdx to ChildCount -1 do
    Child[i].fIndex := i;
end;
//------------------------------------------------------------------------------

function TGroupLayer32.FindLayerNamed(const name: string): TLayer32;
var
  i: integer;
begin
  if SameText(self.Name, name) then
  begin
    Result := self;
    Exit;
  end;

  Result := nil;
  for i := 0 to ChildCount -1 do
  begin
    if Child[i] is TGroupLayer32 then
    begin
      Result := TGroupLayer32(Child[i]).FindLayerNamed(name);
      if assigned(Result) then Break;
    end else if SameText(self.Name, name) then
    begin
      Result := Child[i];
      Break;
    end;
  end;
end;

//------------------------------------------------------------------------------
// THitTestLayer32 class
//------------------------------------------------------------------------------

function THitTestLayer32.GetPathsFromHitTestMask: TPathsD;
var
  i, len: integer;
  tmpImg: TImage32;
  pp: PPointer;
  pc: PColor32;
begin
  Result := nil;
  with fHitTestRec do
  begin
    len := Length(PtrPixels);
    if (len = 0) or (len <> width * height) then Exit;
    tmpImg := TImage32.Create(width, height);
    try
      pc := tmpImg.PixelBase;
      pp := @PtrPixels[0];
      for i := 0 to len -1 do
      begin
        if pp^ <> nil then pc^ := clWhite32;
        inc(pp); inc(pc);
      end;
      result := Vectorize(tmpImg, clWhite32, CompareAlpha, 0);
    finally
      tmpImg.Free;
    end;
  end;
end;

//------------------------------------------------------------------------------
// TVectorLayer32 class
//------------------------------------------------------------------------------

constructor TVectorLayer32.Create(groupOwner: TGroupLayer32;
  const name: string = '');
begin
  inherited;
  fMargin := DpiAware(2);
  fCursorId := crHandPoint;
  fAutoPivot := true;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.Rotate(angleDelta: double);
begin
  if angleDelta = 0 then Exit;
  fAngle := fAngle + angleDelta;
  NormalizeAngle(fAngle);
  fPaths := RotatePath(fPaths, fPivotPt, -angleDelta);
  RepositionAndDraw;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.Rotate(const pivot: TPointD; angleDelta: double);
begin
  if fAutoPivot then
    fPivotPt := MidPoint else
    fPivotPt := pivot;
  Rotate(angleDelta);
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetAngle(newAngle: double);
begin
  Rotate(newAngle - fAngle);
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.ResetAngle;
begin
  fAngle := 0;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetPaths(const newPaths: TPathsD);
begin
  fPaths := CopyPaths(newPaths);
  RepositionAndDraw;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetPivotPt(const pivot: TPointD);
begin
  if fAutoPivot then
    fPivotPt := MidPoint else
    fPivotPt := pivot;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetAutoPivot(val: Boolean);
begin
  fAutoPivot := val;
  if fAutoPivot then fPivotPt := MidPoint;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetBounds(const newBounds: TRect);
var
  w,h, m2: integer;
  dx,dy: double;
  rec: TRect;
  mat: TMatrixD;
begin
  m2 := Margin *2;
  w := RectWidth(newBounds) -m2;
  h := RectHeight(newBounds) -m2;

  //make sure the bounds are large enough to scale safely
  if (Width > m2) and (Height > m2) and (w > 1) and (h > 1)  then
  begin

    //get scaling amounts
    dx := w/(Width - m2);
    dy := h/(Height - m2);

    //apply scaling and translation
    mat := IdentityMatrix;
    rec := Image32_Vector.GetBounds(fPaths);
    MatrixTranslate(mat, -rec.Left, -rec.Top);
    MatrixScale(mat, dx, dy);
    MatrixTranslate(mat, newBounds.Left + Margin, newBounds.Top + Margin);
    MatrixApply(mat, fPaths);

    RepositionAndDraw;
  end else
    inherited;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.Offset(dx,dy: integer);
begin
  inherited;
  fPaths := OffsetPath(fPaths, dx,dy);
  if fAutoPivot then
    fPivotPt := OffsetPoint(fPivotPt, dx,dy);
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.SetMargin(new: integer);
begin
  if fMargin = new then Exit;
  fMargin := new;
  if not Image.IsEmpty then
    RepositionAndDraw;
end;
//------------------------------------------------------------------------------

procedure TVectorLayer32.RepositionAndDraw;
var
  rec: TRect;
begin
  rec := Image32_Vector.GetBounds(fPaths);
  rec := Image32_Vector.InflateRect(rec, Margin, Margin);
  inherited SetBounds(rec);
  if Assigned(fOnDraw) then fOnDraw(self);
end;
//------------------------------------------------------------------------------

procedure  TVectorLayer32.UpdateHitTestMask(const vectorRegions: TPathsD;
  fillRule: TFillRule);
begin
  fHitTestRec.Init(self);
  UpdateHitTestMaskUsingPath(self, vectorRegions, fillRule);
end;

//------------------------------------------------------------------------------
// TRasterLayer32 class
//------------------------------------------------------------------------------

constructor TRasterLayer32.Create(groupOwner: TGroupLayer32; const name: string = '');
begin
  inherited;
  fMasterImg := TLayerNotifyImage32.Create(self);
  fCursorId := crHandPoint;
  fAutoHitTest := true;
end;
//------------------------------------------------------------------------------

destructor TRasterLayer32.Destroy;
begin
  fMasterImg.Free;
  inherited;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.UpdateHitTestMaskOpaque;
var
  i: integer;
  htr: THitTestRec;
  pp: PPointer;
begin
  //fill the entire Hittest mask with self pointers
  with Image do
  begin
    htr.width := Width;
    htr.height := Height;
    SetLength(htr.PtrPixels, Width * Height);
    if not IsEmpty then
    begin
      pp := @htr.PtrPixels[0];
      for i := 0 to High(htr.PtrPixels) do
      begin
        pp^ := self; inc(pp);
      end;
    end;
  end;
  HitTestRec := htr;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.UpdateHitTestMaskTransparent;
begin
  //this method will mark all pixels with an opacity > 127.
  UpdateHitTestMaskUsingImage(fHitTestRec,
    Self, Image, CompareAlpha, clWhite32, 128);
end;
//------------------------------------------------------------------------------

procedure  TRasterLayer32.UpdateHitTestMaskTransparent(
  compareFunc: TCompareFunction;
  referenceColor: TColor32; tolerance: integer);
begin
  UpdateHitTestMaskUsingImage(fHitTestRec, Self, Image,
  compareFunc, referenceColor, tolerance);
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.DoAutoHitTest;
begin
  if fAutoHitTest then
  begin
    if Image.HasTransparency then
      UpdateHitTestMaskTransparent else
      UpdateHitTestMaskOpaque;
  end else
    HitTestRec.Clear;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.ImageChanged(Sender: TImage32);
begin
  if Sender = MasterImage then
  begin
    //reset the layer whenever MasterImage changes
    fAngle := 0;
    fMatrix := IdentityMatrix;
    fRotating := false;
    with MasterImage do
      fSavedSize := Image32_Vector.Size(Width, Height);
    HitTestRec.Clear;
  end else
    inherited;
end;
//------------------------------------------------------------------------------

//SymmetricCropTransparent: after cropping, the image's midpoint
//will be the same pixel as before cropping. (Important for rotating.)
procedure SymmetricCropTransparent(img: TImage32);
var
  w, x,y, x1,y1: Integer;
  newHeight: integer;
  p1,p2: PARGB;
  found: Boolean;
  tmpPxls: TArrayOfColor32;
begin
  w := img.Width;
  y1 := 0;
  found := false;
  for y := 0 to (img.Height div 2) -1 do
  begin
    p1 := PARGB(img.PixelRow[y]);
    p2 := PARGB(img.PixelRow[img.Height - y -1]);
    for x := 0 to w -1 do
    begin
      if (p1.A > 0) or (p2.A > 0) then
      begin
        y1 := y;
        found := true;
        break;
      end;
      inc(p1); inc(p2);
    end;
    if found then break;
  end;

  if not found then
  begin
    img.SetSize(0, 0);
    Exit;
  end;

  if y1 > 0 then
  begin
    //trim top and bottom
    newHeight := img.Height - (y1 * 2);
    SetLength(tmpPxls, w * newHeight);
    Move(img.PixelRow[y1]^, tmpPxls[0], w * newHeight * SizeOf(TColor32));
    img.SetSize(w, newHeight);
    Move(tmpPxls[0], img.PixelBase^ , Length(tmpPxls) * SizeOf(TColor32));
  end;

  x1 := 0;
  found := false;
  for x := 0 to (w div 2) -1 do
  begin
    p1 := PARGB(@img.Pixels[x]);
    p2 := PARGB(@img.Pixels[w - x -1]);
    for y := 0 to img.Height -1 do
    begin
      if (p1.A > 0) or (p2.A > 0) then
      begin
        x1 := x;
        found := true;
        break;
      end;
      inc(p1, w); inc(p2, w);
    end;
    if found then break;
  end;

  if not found then Exit;
  img.Crop(Rect(x1, 0, w - x1, img.Height));
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.SetBounds(const newBounds: TRect);
var
  newWidth, newHeight: integer;
begin
  DoRotateCheck;
  newWidth := RectWidth(newBounds);
  newHeight := RectHeight(newBounds);

  //make sure the image is large enough to scale safely
  if (MasterImage.Width > 1) and (MasterImage.Height > 1) and
    (newWidth > 1) and (newHeight > 1) then
  begin
    BeginUpdate;
    try
      Image.Assign(MasterImage);
      //apply any prior transformations
      AffineTransformImage(Image, fMatrix);
      SymmetricCropTransparent(Image);
      Image.Resize(newWidth, newHeight);
      PositionAt(newBounds.TopLeft);
    finally
      EndUpdate;
    end;
    DoAutoHitTest;
  end else
    inherited;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.Rotate(angleDelta: double);
begin
  if angleDelta = 0 then Exit;
  SetAngle(fAngle + angleDelta);
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.DoRotateCheck;
begin
  if fRotating then
  begin
    fRotating := false;
    //rotation has just ended so add the rotation angle to fMatrix
    if (fAngle <> 0) then
      MatrixRotate(fMatrix, Image.MidPoint, fAngle);
    //and since we're about to start scaling, we need
    //to store the starting size, and reset the angle
    fSavedSize := Size(Image.Width, Image.Height);
    fAngle := 0;
  end;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.DoScaleCheck;
begin
  if not fRotating then
  begin
    //scaling has just ended and rotating is about to start
    //so apply the current scaling to the matrix
    MatrixScale(fMatrix, Image.Width/fSavedSize.cx,
      Image.Height/fSavedSize.cy);
    fRotating := true;
  end;
end;
//------------------------------------------------------------------------------

procedure TRasterLayer32.SetAngle(newAngle: double);
var
  savedMidpoint: TPointD;
begin
  NormalizeAngle(newAngle);
  if MasterImage.IsEmpty or (fAngle = newAngle) then Exit;

  DoScaleCheck;

  fAngle := newAngle;
  savedMidpoint := MidPoint;
  BeginUpdate;
  try
    Image.Assign(MasterImage);
    //apply any prior transformations
    AffineTransformImage(Image, fMatrix);

    Image.Rotate(fAngle);
    //symmetric cropping prevents center wobbling
    SymmetricCropTransparent(Image);
    PositionCenteredAt(savedMidpoint);
    DoAutoHitTest;
  finally
    EndUpdate;
  end;
end;

//------------------------------------------------------------------------------
// TRotatingGroupLayer32 class
//------------------------------------------------------------------------------

function TRotatingGroupLayer32.GetPivot: TPointD;
begin
  Result := Child[1].MidPoint;
end;
//------------------------------------------------------------------------------

function TRotatingGroupLayer32.GetAngle: double;
begin
  Result :=
    Image32_Vector.GetAngle(Child[1].MidPoint, Child[2].MidPoint)  - fZeroOffset;
  NormalizeAngle(Result);
end;
//------------------------------------------------------------------------------

function TRotatingGroupLayer32.GetRotCur: integer;
begin
  Result := Child[2].CursorId;
end;
//------------------------------------------------------------------------------

function TRotatingGroupLayer32.GetDistance: double;
begin
  Result := Image32_Vector.Distance(Child[1].MidPoint, Child[2].MidPoint);
end;
//------------------------------------------------------------------------------

procedure TRotatingGroupLayer32.SetRotCur(curId: integer);
begin
  Child[2].CursorId := curId;
end;

//------------------------------------------------------------------------------
// TDesignerLayer32
//------------------------------------------------------------------------------

procedure  TDesignerLayer32.UpdateHitTestMask(const vectorRegions: TPathsD;
  fillRule: TFillRule);
begin
  fHitTestRec.Init(self);
  UpdateHitTestMaskUsingPath(self, vectorRegions, fillRule);
end;

//------------------------------------------------------------------------------
// TButtonGroupLayer32 class
//------------------------------------------------------------------------------

function TButtonGroupLayer32.AddButton(const pt: TPointD): TButtonDesignerLayer32;
begin
  result := InsertButton(pt, MaxInt);
end;
//------------------------------------------------------------------------------

function TButtonGroupLayer32.InsertButton(const pt: TPointD;
  btnIdx: integer): TButtonDesignerLayer32;
begin
  result := TButtonDesignerLayer32(InsertChild(fBbtnLayerClass, btnIdx));
  with result do
  begin
    SetButtonAttributes(fBtnShape, FBtnSize, fBtnColor);
    PositionCenteredAt(pt);
    CursorId := crHandPoint;
  end;
end;

//------------------------------------------------------------------------------
// TButtonDesignerLayer32 class
//------------------------------------------------------------------------------

procedure TButtonDesignerLayer32.SetButtonAttributes(const shape: TButtonShape;
  size: integer; color: TColor32);
begin
  fSize := size;
  fShape := shape;
  fColor := color;
  size := Ceil(fSize * 1.25); //add room for button shadow
  SetSize(size, size);
  Draw;
end;
//------------------------------------------------------------------------------

procedure TButtonDesignerLayer32.Draw;
begin
  BeginUpdate;
  try
    fButtonOutline := Image32_Extra.DrawButton(Image,
      image.MidPoint, fSize, fColor, fShape, [ba3D, baShadow]);
    UpdateHitTestMask(Image32_Vector.Paths(fButtonOutline), frEvenOdd);
  finally
    EndUpdate;
  end;
end;

//------------------------------------------------------------------------------
// TLayeredImage32 class
//------------------------------------------------------------------------------

constructor TLayeredImage32.Create(Width: integer; Height: integer);
begin
  fRoot          := TGroupLayer32.Create(nil, 'root');
  fRoot.fImageLayer   := self;
  fBounds := Rect(0, 0, Width, Height);
  fRoot.fLocalInvalidRect := fBounds;
end;
//------------------------------------------------------------------------------

destructor TLayeredImage32.Destroy;
begin
  fRoot.Free;
  inherited;
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.SetSize(width, height: integer);
begin
  fBounds := Rect(0, 0, Width, Height);
  fRoot.SetBounds(fBounds);
  fRoot.fLocalInvalidRect := fBounds;
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetMergedImage(hideDesigners: Boolean): TImage32;
var
  updateRect: TRect;
begin
  Root.fLocalInvalidRect := fBounds; //forces a full repaint
  Result := GetMergedImage(hideDesigners, updateRect);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetMergedImage(hideDesigners: Boolean;
  out updateRect: TRect): TImage32;
var
  mergeAll: Boolean;
begin
  updateRect := NullRect;
  mergeAll := fPreviousHideDesignerState <> hideDesigners;
  Root.MergeInvalidatedRects(mergeAll, hideDesigners, updateRect);
  if mergeAll then
    updateRect := fBounds else
    updateRect := Image32_Vector.IntersectRect(updateRect, fBounds);
  Root.SetBounds(fBounds);
  if fBackColor <> clNone32 then
    Root.Image.FillRect(updateRect, fBackColor);
  Root.Merge(hideDesigners, updateRect);
  Result := Root.Image;

  fPreviousHideDesignerState := hideDesigners;
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.Clear;
begin
  fRoot.Image.Clear(fBackColor); //check
  fRoot.ClearChildren;
  fPreviousHideDesignerState := false;
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.Invalidate;
begin
  fRoot.fLocalInvalidRect := fBounds;
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetRootLayersCount: integer;
begin
  Result := fRoot.ChildCount;
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetLayer(index: integer): TLayer32;
begin
  Result := fRoot[index];
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetImage: TImage32;
begin
  Result := fRoot.Image;
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetHeight: integer;
begin
  Result := RectHeight(fBounds);
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.SetHeight(value: integer);
begin
  if Height <> value then SetSize(Width, value);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetWidth: integer;
begin
  Result := RectWidth(fBounds);
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.SetWidth(value: integer);
begin
  if Width <> value then SetSize(value, Height);
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.SetBackColor(color: TColor32);
begin
  if color = fBackColor then Exit;
  fBackColor := color;
  Invalidate;
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetMidPoint: TPointD;
begin
  Result := PointD(Width * 0.5, Height * 0.5);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.AddLayer(layerClass: TLayer32Class;
  group: TGroupLayer32; const name: string): TLayer32;
begin
  if not Assigned(layerClass) then layerClass := TLayer32;
  Result := InsertLayer(layerClass, group, MaxInt, name);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.InsertLayer(layerClass: TLayer32Class;
  group: TGroupLayer32; index: integer; const name: string): TLayer32;
begin
  if not Assigned(group) then group := fRoot;
  Result := group.InsertChild(layerClass, index, name);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.FindLayerNamed(const name: string): TLayer32;
begin
  Result := Root.FindLayerNamed(name);
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.DeleteLayer(layer: TLayer32);
begin
  if not assigned(layer) or not assigned(layer.fGroupOwner) then Exit;
  layer.fGroupOwner.DeleteChild(layer.Index);
end;
//------------------------------------------------------------------------------

procedure TLayeredImage32.DeleteLayer(layerIndex: integer;
  groupOwner: TGroupLayer32 = nil);
begin
  if not assigned(groupOwner) then groupOwner := Root;
  if (layerIndex < 0) or (layerIndex >= groupOwner.ChildCount) then
    raise Exception.Create(rsChildIndexRangeError);
  groupOwner.DeleteChild(layerIndex);
end;
//------------------------------------------------------------------------------

function TLayeredImage32.GetLayerAt(const pt: TPoint; ignoreDesigners: Boolean): TLayer32;
begin
  result := Root.GetLayerAt(pt, ignoreDesigners);
end;

//------------------------------------------------------------------------------
// Miscellaneous button functions
//------------------------------------------------------------------------------

function GetRectEdgeMidPoints(const rec: TRectD): TPathD;
var
  mp: TPointD;
begin
  mp := MidPoint(rec);
  SetLength(Result, 4);
  Result[0] := PointD(mp.X, rec.Top);
  Result[1] := PointD(rec.Right, mp.Y);
  Result[2] := PointD(mp.X, rec.Bottom);
  Result[3] := PointD(rec.Left, mp.Y);
end;
//------------------------------------------------------------------------------

function CreateSizingButtonGroup(targetLayer: TLayer32;
  sizingStyle: TSizingStyle; buttonShape: TButtonShape;
  buttonSize: integer; buttonColor: TColor32;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TSizingGroupLayer32;
var
  i: integer;
  rec: TRectD;
  corners, edges: TPathD;
const
  cnrCursorIds: array [0..3] of integer =
    (crSizeNWSE, crSizeNESW, crSizeNWSE, crSizeNESW);
  edgeCursorIds: array [0..3] of integer =
    (crSizeNS, crSizeWE, crSizeNS, crSizeWE);
begin
  if not assigned(targetLayer) or
    not (targetLayer is THitTestLayer32) then
      raise Exception.Create(rsCreateButtonGroupError);
  Result := TSizingGroupLayer32(
    targetLayer.RootOwner.AddLayer(TSizingGroupLayer32,
    nil, rsSizingButtonGroup));
  Result.BeginUpdate;
  try
    Result.SizingStyle := sizingStyle;
    rec := RectD(targetLayer.Bounds);
    corners := Rectangle(rec);
    edges := GetRectEdgeMidPoints(rec);

    if not assigned(buttonLayerClass) then
      buttonLayerClass := TButtonDesignerLayer32;

    for i := 0 to 3 do
    begin
      if sizingStyle <> ssEdges then
      begin
        with TButtonDesignerLayer32(Result.AddChild(
          buttonLayerClass, rsButton)) do
        begin
          SetButtonAttributes(buttonShape, buttonSize, buttonColor);
          PositionCenteredAt(corners[i]);
          CursorId := cnrCursorIds[i];
        end;
      end;
      if sizingStyle <> ssCorners then
      begin
        with TButtonDesignerLayer32(Result.AddChild(
          buttonLayerClass, rsButton)) do
        begin
          SetButtonAttributes(buttonShape, buttonSize, buttonColor);
          PositionCenteredAt(edges[i]);
          CursorId := edgeCursorIds[i];
        end;
      end;
    end;
  finally
    Result.EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function UpdateSizingButtonGroup(movedButton: TLayer32): TRect;
var
  i: integer;
  path, corners, edges: TPathD;
  group: TSizingGroupLayer32;
  rec: TRectD;
begin
  //nb: it may be tempting to store the targetlayer parameter in the
  //CreateSizingButtonGroup function call and automatically update its
  //bounds here, except that there are situations where blindly updating
  //the target's bounds using the returned TRect is undesirable
  //(eg when targetlayer needs to preserve its width/height ratio).
  Result := NullRect;
  if not assigned(movedButton) or
    not (movedButton is TButtonDesignerLayer32) or
    not (movedButton.GroupOwner is TSizingGroupLayer32) then Exit;

  group := TSizingGroupLayer32(movedButton.GroupOwner);
  with group do
  begin
    SetLength(path, ChildCount);
    for i := 0 to ChildCount -1 do
      path[i] := Child[i].MidPoint;
  end;
  rec := GetBoundsD(path);

  case group.SizingStyle of
    ssCorners:
      begin
        if Length(path) <> 4 then Exit;
        with movedButton.MidPoint do
        begin
          case movedButton.Index of
            0: begin rec.Left := X; rec.Top := Y; end;
            1: begin rec.Right := X; rec.Top := Y; end;
            2: begin rec.Right := X; rec.Bottom := Y; end;
            3: begin rec.Left := X; rec.Bottom := Y; end;
          end;
        end;
        corners := Rectangle(rec);
        with group do
          for i := 0 to 3 do
            Child[i].PositionCenteredAt(corners[i]);
      end;
    ssEdges:
      begin
        if Length(path) <> 4 then Exit;
        with movedButton.MidPoint do
        begin
          case movedButton.Index of
            0: rec.Top := Y;
            1: rec.Right := X;
            2: rec.Bottom := Y;
            3: rec.Left := X;
          end;
        end;
        edges := GetRectEdgeMidPoints(rec);
        with group do
          for i := 0 to 3 do
            Child[i].PositionCenteredAt(edges[i]);
      end;
    else
      begin
        if Length(path) <> 8 then Exit;
        with movedButton.MidPoint do
        begin
          case movedButton.Index of
            0: begin rec.Left := X; rec.Top := Y; end;
            1: rec.Top := Y;
            2: begin rec.Right := X; rec.Top := Y; end;
            3: rec.Right := X;
            4: begin rec.Right := X; rec.Bottom := Y; end;
            5: rec.Bottom := Y;
            6: begin rec.Left := X; rec.Bottom := Y; end;
            7: rec.Left := X;
          end;
        end;
        corners := Rectangle(rec);
        edges := GetRectEdgeMidPoints(rec);
        with group do
          for i := 0 to 3 do
          begin
            Child[i*2].PositionCenteredAt(corners[i]);
            Child[i*2 +1].PositionCenteredAt(edges[i]);
          end;
      end;
  end;
  Result := Rect(rec);
end;
//------------------------------------------------------------------------------

function GetMaxToDistRectFromPointInRect(const pt: TPointD;
  const rec: TRectD): double;
var
  d: double;
begin
  with rec do
  begin
    Result := Distance(pt, TopLeft);
    d := Distance(pt, PointD(Right, Top));
    if d > Result then Result := d;
    d := Distance(pt, BottomRight);
    if d > Result then Result := d;
    d := Distance(pt, PointD(Left, Bottom));
    if d > Result then Result := d;
  end;
end;
//------------------------------------------------------------------------------

function CreateRotatingButtonGroup(targetLayer: TLayer32;
  const pivot: TPointD; buttonSize: integer;
  centerButtonColor, movingButtonColor: TColor32;
  startingAngle: double; startingZeroOffset: double;
  buttonLayerClass: TButtonDesignerLayer32Class): TRotatingGroupLayer32;
var
  rec, rec2: TRectD;
  pt: TPoint;
  radius, i: integer;
begin
  if not assigned(targetLayer) or
    not (targetLayer is THitTestLayer32) then
      raise Exception.Create(rsCreateButtonGroupError);

  Result := TRotatingGroupLayer32(targetLayer.RootOwner.AddLayer(
    TRotatingGroupLayer32, nil, rsRotatingButtonGroup));

  //startingZeroOffset: default = 0 (ie 3 o'clock)
  Result.fZeroOffset := startingZeroOffset;

  if buttonSize <= 0 then buttonSize := DefaultButtonSize;

  rec := RectD(targetLayer.Bounds);
  radius := Round(GetMaxToDistRectFromPointInRect(pivot, rec));

  with Result.AddChild(TDesignerLayer32) do     //Layer 0 - design layer
  begin
    rec2 := RectD(pivot.x -radius, pivot.y -radius,
      pivot.x +radius, pivot.y +radius);
    SetBounds(Rect(rec2));
    i := DPIAware(2);
    DrawDashedLine(Image, Ellipse(Rect(i,i,radius*2 -i, radius*2 -i)),
      dashes, nil, i, clRed32, esPolygon);
  end;

  if not assigned(buttonLayerClass) then
    buttonLayerClass := TButtonDesignerLayer32;

  Result.BeginUpdate;
  try
    with TButtonDesignerLayer32(Result.AddChild(  //Layer 1 - center button
      buttonLayerClass, rsButton)) do
    begin
      SetButtonAttributes(bsRound, buttonSize, centerButtonColor);
      PositionCenteredAt(pivot);
      HitTestRec.Clear;
    end;

    with TButtonDesignerLayer32(Result.AddChild(  //layer 2 - rotating button
      buttonLayerClass, rsButton)) do
    begin
      SetButtonAttributes(bsRound, buttonSize, movingButtonColor);

      pt := Point(GetPointAtAngleAndDist(pivot,
        -(startingAngle + startingZeroOffset), radius));
      PositionCenteredAt(pt);

      CursorId := crHandPoint;
    end;
  finally
    Result.EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function CreateRotatingButtonGroup(targetLayer: TLayer32;
  buttonSize: integer = 0;
  centerButtonColor: TColor32 = clWhite32;
  movingButtonColor: TColor32 = clBlue32;
  startingAngle: double = 0; startingZeroOffset: double = 0;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TRotatingGroupLayer32;
var
  pivot: TPointD;
begin
  pivot := PointD(Image32_Vector.MidPoint(targetLayer.Bounds));
  Result := CreateRotatingButtonGroup(targetLayer, pivot, buttonSize,
  centerButtonColor, movingButtonColor, startingAngle, startingZeroOffset,
  buttonLayerClass);
end;
//------------------------------------------------------------------------------

function UpdateRotatingButtonGroup(rotateButton: TLayer32): double;
var
  rec: TRect;
  mp, pt2: TPointD;
  i, radius: integer;
begin
  if not assigned(rotateButton) or
    not (rotateButton.GroupOwner is TRotatingGroupLayer32) then
      raise Exception.Create(rsUpdateRotateGroupError);

  with TRotatingGroupLayer32(rotateButton.GroupOwner) do
  begin
    Invalidate(Child[0].bounds);
    mp := Child[1].MidPoint;
    pt2 := rotateButton.MidPoint;
    radius := Round(Distance(mp, pt2));
    rec := Rect(RectD(mp.X -radius, mp.Y -radius, mp.X +radius,mp.Y +radius));
    Child[0].SetBounds(rec);
    i :=  DPIAware(2);
    DrawDashedLine(Child[0].Image, Ellipse(Rect(i,i,radius*2 -i, radius*2 -i)),
      dashes, nil, i, clRed32, esPolygon);
    Result := Image32_Vector.GetAngle(mp, pt2) - fZeroOffset;
    NormalizeAngle(Result);
  end;
end;
//------------------------------------------------------------------------------

function CreateButtonGroup(groupOwner: TGroupLayer32;
  const buttonPts: TPathD; buttonShape: TButtonShape;
  buttonSize: integer; buttonColor: TColor32;
  buttonLayerClass: TButtonDesignerLayer32Class = nil): TButtonGroupLayer32;
var
  i: integer;
begin
  if not assigned(groupOwner) then
    raise Exception.Create(rsCreateButtonGroupError);

  Result := TButtonGroupLayer32(groupOwner.AddChild(TButtonGroupLayer32));
  if not assigned(buttonLayerClass) then
    buttonLayerClass := TButtonDesignerLayer32;

  Result.fBtnSize := buttonSize;
  Result.fBtnShape := buttonShape;
  Result.fBtnColor := buttonColor;
  Result.fBbtnLayerClass := buttonLayerClass;

  Result.BeginUpdate;
  try
    for i := 0 to high(buttonPts) do
      Result.AddButton(buttonPts[i]);
  finally
    Result.EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure InitDashes;
var
  i: integer;
begin
  i := DPIAware(2);
  setLength(dashes, 2);
  dashes[0] := i; dashes[1] := i*2;
end;

initialization
  InitDashes;
  DefaultButtonSize := DPIAware(10);

end.
