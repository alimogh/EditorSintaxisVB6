VERSION 5.00
Begin VB.UserControl ctlEdit 
   ClientHeight    =   1725
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   2925
   ScaleHeight     =   1725
   ScaleWidth      =   2925
   Begin VB.ListBox lstCont 
      Appearance      =   0  'Flat
      BackColor       =   &H00FFFFFF&
      Height          =   420
      Left            =   45
      TabIndex        =   3
      TabStop         =   0   'False
      Top             =   45
      Width           =   1095
   End
   Begin VB.HScrollBar HScroll1 
      Height          =   255
      Left            =   120
      TabIndex        =   2
      TabStop         =   0   'False
      Top             =   840
      Width           =   1215
   End
   Begin VB.VScrollBar VScroll1 
      Height          =   1215
      Left            =   1920
      TabIndex        =   1
      TabStop         =   0   'False
      Top             =   0
      Width           =   255
   End
   Begin VB.Timer Timer1 
      Interval        =   250
      Left            =   1320
      Top             =   360
   End
   Begin VB.PictureBox pic 
      BeginProperty Font 
         Name            =   "Courier New"
         Size            =   8.25
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   1095
      Left            =   240
      OLEDropMode     =   1  'Manual
      ScaleHeight     =   1035
      ScaleWidth      =   1275
      TabIndex        =   0
      Top             =   0
      Width           =   1335
   End
End
Attribute VB_Name = "ctlEdit"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'                            Control editor de texto.
' Este c�digo fuente puede ser usado, modificado y redistribuido libremente de acuerdo
' a su libre criterio, con solo indicar como referencia al autor.
'
'Implementa las principales funciones de un editor de texto plano. S�lo
'trabaja con tipos de letra de ancho de caracter constante.
'No utiliza ning�n control "TextBox" o "RichTextBox". Esta optimizado en velocidad
'y maneja bien archivos de hasta 50000 l�neas.
'
'Las principales propiedades son:
'
'"verNumLin".- Permite mostrar el n�mero de l�nea activando la propiedad
'"verDesHor".- Permite activar la barra de desplazamiento horizontal.
'"bloqText".- Bloquea el contenido de modificaci�n. Lo convierte en un visor.
'"TipoSelec".- Define el tipo de selecci�n 0=Normal; 1=Por columnas

'En el desarrollo del programa se han considerado dos tipos de coordenadas:
' *Coordenadas del cursor.- Refrentes a la posici�n relativa del cursor con respecto
'  a la pantalla. La esquina superior izquierda es siempre la posici�n (1,1). Las
'  variables que se refieren a coordenadas del cursor, son de tipo xc, yc
' *Coordenadas del texto.- Referentes a la posici�n relativa de un caracter con
'  respecto al texto completo como si estuviera impreso en una hoja suficientemente
'  grande. El texto se ve con las tabulaciones expandidas. La posici�n (1,1) es
'  siempre el primer caracter del texto. Las variables que se refieren a coordenadas
'  del texto, son de tipo xt, yt
'
'Se debe mejorar:
'* Verificar la administraci�n de memoria din�mica. No se ha revisado detalladamente.
'* El desplazamiento con la barra vertical para m�s de 32000 l�neas
'* Agregar la opci�n de edici�n con reemplazo.
'* Mejorarse las opciones de "deshacer" en modo columna.
'* Agregar la opci�n "Rehacer".
'* Mejorar la opci�n de b�squeda. Agregar Reemplazo.
'
'                                           Iniciado por Tito Hinostroza 27/10/2008
'                                         Continuado por Tito Hinostroza 28/10/2009
'                                         Modificado por Tito Hinostroza 25/11/2009
'                                         Modificado por Tito Hinostroza 11/12/2009
'                                         Modificado por Tito Hinostroza 06/01/2010
'                                         Modificado por Tito Hinostroza 19/01/2010
'
'                       Modificado por Tito Hinostroza 12/02/2010 Lima - Per�
'
'Se ha agregado opciones de dibujo de texto con color.
'Se ha mejorado el manejo de la opci�n de deshacer en modo columna. A�n hay varios
'aspectos por mejorar.
'Se ha agregado la acci�n de cambio de modo de selecci�n como acci�n para deshacer
'
'                       Modificado por Tito Hinostroza 19/04/2010
'                       Modificado por Tito Hinostroza 02/06/2010
'Se mejor� la funci�n de b�squeda, corrigiendo las rutinas.
'Se optimiz� la rutina Dibujar(), controlando el evento Paint() del "Picture"
'                       Modificado por Tito Hinostroza 14/06/2010
'Se mejor� el modo de inserci�n en modo columna para poder insertar varios
'caracteres sin seleccionar varias veces.
'Se cre� el evento CambiaModo para gestionar mejor el cambio de modo del editor
'con la combinaci�n ALt-C, ya que los men�s no responden a esta combinaci�n de
'teclas.

Option Explicit

Const MAX_ANC_LIN = 32766    'Ancho m�ximo de l�nea en caracteres. < 32767
Const TAM_MAX_UNDO = 1000000 'Tama�o m�ximo de bytes usados en "Deshacer"
Const NAC_MAX_UNDO = 60      'N�mero m�ximo de acciones "Deshacer"

'Direcciones de ajuste horizontal para posicionar el cursor
Const A_NULO = 0
Const A_IZQ_TAB = 1
Const A_DER_TAB = 2

'Caracteres de desplazamiento por palabra
Const CAR_DESP_PAL = "[a-zA-Z0-9_$'.����������-]"
Const CAR_IDEN_VALM = "[A-Z0-9_$������]"    'caracteres v�lidos para identificador (may�scula)

Private Const GMEM_MOVEABLE = 2
Private Const GMEM_DDESHARE = &H2000

Public Event ArchivoSoltado(arc As String)  'Evento para archivo soltado
'Public Event TeclaEscape()                 'Indica la pulsaci�n de la tecla escape
Public Event CambiaModo()     'Indica una solicitud de cambio de modo. El editor
                              'lo pide con la tecla ALt-C.
Public Event KeyDown(KeyCode As Integer, Shift As Integer)  'Tecla pulsada


Private Declare Function SelectObject Lib "gdi32" (ByVal hdc As Long, ByVal hObject As Long) As Long
Private Declare Function CreatePen Lib "gdi32" (ByVal nPenStyle As Long, ByVal nWidth As Long, ByVal crColor As Long) As Long
Private Declare Function Rectangle Lib "gdi32" (ByVal hdc As Long, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long) As Long
Private Declare Function CreateSolidBrush Lib "gdi32" (ByVal crColor As Long) As Long
Private Declare Function FillRect Lib "user32.dll" (ByVal hdc As Long, lpRect As RECT, ByVal hBrush As Long) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long

Private Declare Function CloseClipboard Lib "user32" () As Long
Private Declare Function OpenClipboard Lib "user32" (ByVal hWnd As Long) As Long
Private Declare Function EmptyClipboard Lib "user32" () As Long
Private Declare Function SetClipboardData Lib "user32" (ByVal wFormat As Long, ByVal hMem As Long) As Long

Const CF_TEXT = 1
Const GHND = &H42

Private Declare Function TextOut Lib "gdi32" Alias "TextOutA" ( _
    ByVal hdc As Long, ByVal x As Long, ByVal y As Long, _
    ByVal lpString As String, ByVal nCount As Long) As Long
Private Declare Function SetTextColor Lib "gdi32" (ByVal hdc As Long, ByVal crColor As Long) As Long
Private Declare Function SetTextAlign Lib "gdi32" (ByVal hdc As Long, _
    ByVal wFlags As Long) As Long
  
Const TA_LEFT = 0
Const TA_RIGHT = 2
Const TA_CENTER = 6
Const TA_TOP = 0
Const TA_BOTTOM = 8
Const TA_BASELINE = 24

'Variables generales
Public archivo As String    'archivo a cargar con el m�todo "CargarArch"



Public nEspTab As Integer   'n�mero de espacios por tabulaci�n
Public verNumLin As Boolean 'Muestra n�mero de l�nea
Public verDesHor As Boolean 'Muestra barra de desplazamiento horizontal
Public verDesVer As Boolean 'Muestra barra de desplazamiento vertical

Public bloqText As Boolean   'bloquea el texto para modificaci�n
Private tipSelec As Integer  'tipo de selecci�n de texto
Public tipArch As Integer   'tipo de archivo: 0->DOS 1->UNIX
Public menuContext As Menu  'referencia al men� contextual del Editor

Private ancNLinP As Integer 'ancho de la columna de n�mero de l�neas en pixeles
'Variables de colores de texto
Private mColFonEdi As Long  'color de fondo del control de edici�n
Private mColFonSel As Long  'color del fondo de la selecci�n
Private mColTxtNor As Long  'color de texto normal
Private mColTxtSel As Long  'color del texto de la selecci�n
Private mColFonNli As Long  'color de fondo para n�mero de l�nea

Private mColTxtCom As Long  'color de comentarios
Private mColTxtCad As Long  'color de constantes cadenas
Private mColPalRes As Long  'color de palabras Reservadas
Private mColPalRes2 As Long  'color de palabras Reservadas
Private mColTxtFun As Long  'color de palabras Reservadas

Public nlin As Long         'n�mero de l�neas del texto

Private fil1 As Long        'n�mero de fila inicial en el control
Private fil2 As Long        'n�mero de fila final en el control
Private nfilFin As Long     'n�mero de fila final a mostrar en el control
Private maxLinVis As Integer  'm�ximo n�mero de l�neas visibles (que caben en la ventana)

Private col1 As Integer       'n�mero de columna inicial en el control
Private col2 As Integer       'n�mero de columna final en el control
Private maxColVis As Integer  'm�ximo n�mero de columnas visibles (que caben en la ventana)
Private maxTamLin As Integer  'ancho m�ximo de las l�neas

Private pintando As Boolean  'bandera usada por el evento "Paint"
Private Redibujar As Boolean 'bandera que indica que se debe redibujar el control
Private msjError As String   'Mensaje de error

'Variables de manejo de la selecci�n
Public haysel As Boolean    'Indica si hay un bloque seleccionado
Private sel1 As Tpostex     'Posici�n inicial de la selecci�n
Private sel2 As Tpostex     'Posici�n final de la selecci�n
Private sel0 As Tpostex     'Posici�n donde se empieza a marcar la selecci�n
Private sel1ant As Tpostex  'sel1 anterior
Private sel2ant As Tpostex  'sel2 anterior

'Variables de manejo del cursor
Private curXt As Integer    'n�mero de caracter que apunta el cursor en coord. del texto
Private curYt As Long       'n�mero de l�nea que apunta el cursor en coord. del texto
Private curXd As Integer    'coordenada X de cursor deseada. Se usa para desplazarse por l�neas
Private curXt_ant As Integer 'posici�n anterior X del cursor con respecto a la ventana
Private curYt_ant As Long    'posici�n anterior Y del cursor con respecto a la ventana
Private curBorrado As Boolean   'Para controlar el parpadeo del cursor

Private xt0 As Integer      'coordenada X de cursor inicial. Usado para selecci�n con rat�n
Private yt0 As Long         'coordenada Y de cursor inicial. Usado para selecci�n con rat�n
Private curtmp As Integer   'contador para temporizar el parpadeo del cursor
Private linact As String    'l�nea actual completa apuntada por el cursor
Private cursorOn As Boolean 'bandera para activar o desactivar el cursor

Private anccarP As Single    'ancho de caracter en pixeles
Private altcarP As Single    'ancho de caracter en pixeles

'Variables para control de pantalla
Const MAX_LIN_EDI = 100000      'M�xima cantidad de l�neas que soporta el editor
Const MAX_LIN_COL = 1000        'M�xima cantidad de l�neas que se soportan con coloreado de sintaxis
Private linrea() As String      'texto cargado en el editor en l�neas
Private lincol() As TdesLin     'Descripci�n de colores de L�neas para gr�ficar
Private deslin() As TDesSeg     'Para manejo de descripci�n de l�nea

Private pulsadoI As Boolean     'bandera de bot�n Izquierdo pulsado
Private ultBotPul As Integer    '�tlimo bot�n pulsado
Private facdesV  As Single      'factor de desplazamiento

'Variables de los m�todos gr�ficos
Private tR As RECT, tTR As RECT

Private hPen As Long            'lap�z nuevo
Private hBrush As Long          'brocha para el PIC
Private hFont As Long           'fuente
Private ret_pt As POINTAPI      'punto POINTAPI para uso temporal

'Variables para manejo de tabulaciones
Private ptabexp() As Integer    'posiciones de inicio de las tabulaciones en el texto expandido
Private ptabrea() As Integer    'posiciones real de las tabulaciones en el texto

'Variable para el control de la opci�n DESHACER
Private Undos() As Tundo       'Comandos deshacer
Public nUndo As Integer        'N�mero de acciones en Undos
Private nTxtModif As Integer   'Indice al nUndo que da el texto sin modificar
Private Deshaciendo As Boolean

'Variables para el control de la b�squeda
Private PosBus1 As Tpostex  'Posici�n inicial del texto buscado.
Private PosBus2 As Tpostex  'Posici�n final del texto buscado.
Private CadBus As String    'Cadena de b�squeda
Private CajBus As Boolean   'Bandera de caja para b�squeda
Private PalCBus As Boolean  'Bandera de palabra completa para b�squeda
Private DirBus As Integer   'Direcci�n de b�squeda
Private PosEnc As Tpostex   'Posici�n del texto encontrado. Usado para b�squedas

'Variables para ayuda contextual
Private HayAyudC As Boolean 'bandera de men� de Ayuda Contextual activa
Private xCont0 As Long      'Coordenada inicial de men� contextual
Private yCont0 As Long      'Coordenada final de men� contextual
Private xtIniIden As Integer    'Columna de inicio de identificador
Private ytIniIden As Long       'Fila de inicio de identificador
Private ancMenCon As Long       'Ancho de men� contextual
Private altMenCon As Long
Private IdentAyudC() As String  'Guarda los identificadores de la ayuda contextual
Private nFilAyudC As Integer    'N�mero de filas a mostrar en el men�
Private ListandoTab As Boolean
Private ArcListaTab As String   'Archivo de lista de Tablas
Private ListaTablas() As String 'Guarda los nombres de las tablas

'*************************************************************************************
'********************************FUNCIONES DE BAJO NIVEL******************************
'*************************************************************************************
Private Function Posit(num As Single) As Single
'Devuelve siempre un n�mero positivo o cero
    If num < 0 Then Posit = 0 Else Posit = num
End Function

Public Property Get TipoSelec() As Integer
    TipoSelec = tipSelec
End Property

Public Property Let TipoSelec(ByVal vNewValue As Integer)
    If tipSelec <> vNewValue Then
        If vNewValue = 0 Then  'Pasa a modo normal
            GuarAcc TU_SNOR, LeePosCur(), ""     'para deshacer
        Else                'Pasa a modo por columna
            GuarAcc TU_SCOL, LeePosCur(), ""     'para deshacer
        End If
        tipSelec = vNewValue
    End If
End Property
'------------Lectura de colores--------------
Public Property Get ColFonEdi() As Long: ColFonEdi = mColFonEdi: End Property
Public Property Get ColFonSel() As Long: ColFonSel = mColFonSel: End Property
Public Property Get ColTxtNor() As Long: ColTxtNor = mColTxtNor: End Property
Public Property Get ColTxtSel() As Long: ColTxtSel = mColTxtSel: End Property
Public Property Get ColFonNli() As Long: ColFonNli = mColFonNli: End Property

Public Property Get ColTxtCom() As Long: ColTxtCom = mColTxtCom: End Property
Public Property Get ColTxtCad() As Long: ColTxtCad = mColTxtCad: End Property
Public Property Get ColPalRes() As Long: ColPalRes = mColPalRes: End Property
Public Property Get ColPalRes2() As Long: ColPalRes2 = mColPalRes2: End Property
Public Property Get ColTxtFun() As Long: ColTxtFun = mColTxtFun: End Property

'------------Escritura de colores--------------
Public Property Let ColFonEdi(ByVal vNewValue As Long)
    If mColFonEdi <> vNewValue Then
        mColFonEdi = vNewValue  'lee nuevo valor
        pic.BackColor = mColFonEdi  'Actualiza color de fondo
    End If
End Property

Public Property Let ColFonSel(ByVal vNewValue As Long): mColFonSel = vNewValue: End Property
Public Property Let ColTxtSel(ByVal vNewValue As Long): mColTxtSel = vNewValue: End Property
Public Property Let ColTxtNor(ByVal vNewValue As Long): mColTxtNor = vNewValue: End Property
Public Property Let ColFonNli(ByVal vNewValue As Long): mColFonNli = vNewValue: End Property

Public Property Let ColTxtCom(ByVal vNewValue As Long): mColTxtCom = vNewValue: End Property
Public Property Let ColTxtCad(ByVal vNewValue As Long): mColTxtCad = vNewValue: End Property
Public Property Let ColPalRes(ByVal vNewValue As Long): mColPalRes = vNewValue: End Property
Public Property Let ColPalRes2(ByVal vNewValue As Long): mColPalRes2 = vNewValue: End Property
Public Property Let ColTxtFun(ByVal vNewValue As Long): mColTxtFun = vNewValue: End Property
'------------------------------------------------
Private Function MaxCol1() As Integer
'Devuelve el m�ximo valor que puede tomar "col1"
    'Deber�a ser maxTamLin - maxColVis + 1, pero el cursor
    'se puede mover hasta len(linea)+1.
    MaxCol1 = maxTamLin - maxColVis + 2
    If MaxCol1 < 1 Then MaxCol1 = 1 'protecci�n
End Function

Private Function CarXY(xt As Integer, ByVal yt As Long) As String
'Devuelve el caracter de la posici�n X,Y de la ventana visible.
Dim lin As String
    'Verifica si escapa de la pantalla
    If xt < col1 Or xt > col2 Then CarXY = " ": Exit Function
    If yt < 1 Or yt > nlin Then CarXY = " ": Exit Function
    'toma l�nea afectada
    lin = linexp(yt)
    'Verifica si escapa de la l�nea mostrada
    If xt > Len(lin) Then CarXY = " ": Exit Function
    'Toma caracter
    CarXY = Mid$(lin, xt, 1)
End Function

Private Function CarPos(p As Tpostex) As String
'Devuelve el caracter actual de una posici�n. Coordenadas de texto
Dim lin As String
Dim xt As Integer
    lin = linrea(p.yt)    'lee primera l�nea
    xt = PosXTreal(p.xt, p.yt)
    CarPos = Mid$(lin, xt, 1)
End Function

Private Function CarPosAnt(p As Tpostex) As String
'Devuelve el caracter anterior a una posici�n. Coordenadas de texto
'Si el caracter es el primero de una l�nea, se devuelve cadena vac�a
Dim lin As String
Dim xt As Integer
    lin = linrea(p.yt)    'lee primera l�nea
    xt = PosXTreal(p.xt, p.yt)
    If xt <= 1 Then Exit Function    'protecci�n
    CarPosAnt = Mid$(lin, xt - 1, 1)
End Function

Private Function CarPosSig(p As Tpostex) As String
'Devuelve el caracter siguiente a una posici�n. Coordenadas de texto
'Si el caracter es el �ltimo de una l�nea, se devuelve cadena vac�a
Dim lin As String
Dim xt As Integer
    lin = linrea(p.yt)    'lee primera l�nea
    xt = PosXTreal(p.xt, p.yt)
    If xt >= Len(lin) + 1 Then Exit Function    'protecci�n
    CarPosSig = Mid$(lin, xt + 1, 1)
End Function

Private Function ColXY(xt As Integer, yt As Long) As Long
'Devuelve el color de la posici�n X,Y en la ventana visible
'Coordenadas del cursor
Dim lin() As TDesSeg
Dim i As Integer
Dim pos As Integer
Dim txt As String
    'Verifica si escapa de la pantalla
    If xt < col1 Or xt > col2 Then Exit Function
    If yt < 1 Or yt > nlin Then Exit Function
    'Lee o actualiza el vector de descripci�n
    If lincol(yt).tip = TLIN_DES Then
        'Auqnue no es trabajo de ColXY() ver el color
        'Pueda que a veces tenga que hacerlo
        txt = linexp(yt)                'lee toda la l�nea
        ActualDescColFil txt, lin()
        lincol(yt).tip = TLIN_MIX
        lincol(yt).seg = lin    'copia descripci�n de l�nea
    Else    'ya tiene descripci�n de segmento
        lin = lincol(yt).seg
    End If
    
    'Explora el vector de descripci�n
    '-------Busca segmento de inicio "i"-------
    i = 1   'Se asume que empieza en el segmento 1
    pos = 1
    For i = 1 To UBound(lin)
        pos = pos + lin(i).tam
        If pos > xt Then
            'Este es el segmento que contiene al caracter.
            ColXY = lin(i).col  'toma color
            Exit Function
        End If
    Next
    'Est� al final de la l�nea, o no hay descripci�n
    ColXY = vbBlack
End Function

Private Sub BorCursorXY()
'Borra el cursor de la posici�n (curXt_ant, curYt_ant), redibujando
'el caracter XY (coordenadas de cursor) en la pantalla.
Dim car As String
Dim hdc As Long
Dim posX As Long, posY As Long
    'Verifica si cae fuera de la pantalla
    If curYt_ant < fil1 Or curYt_ant > fil2 Then Exit Sub
    hdc = pic.hdc
    posX = anccarP * (curXt_ant - col1)     '+ ancNLinP
    posY = altcarP * (curYt_ant - fil1)
    'primero dibuja fondo para borrar las marcas anteriores
    FijaRelleno mColFonEdi
    FijaLapiz PS_SOLID, 1, mColFonEdi
    Rectangle hdc, posX, posY, posX + anccarP, posY + altcarP
    'redibuja caracter
    car = CarXY(curXt_ant, curYt_ant)
    pic.ForeColor = ColXY(curXt_ant, curYt_ant)
    SetTextAlign hdc, TA_LEFT
    TextOut hdc, posX, posY, car, Len(car)
    curBorrado = True   'marca bandera
End Sub

Private Sub DibCursorXY()
'Dibuja el s�mbolo del cursor en la posici�n (curXt, curYt)
'en la pantalla. Actualiza (curXt_ant, curYt_ant)
Dim car As String
Dim hdc As Long
Dim posX As Long, posY As Long
Dim posXfin As Long, posYfin As Long
    posX = anccarP * (curXt - col1)     '+ ancNLinP
    posY = altcarP * (curYt - fil1)
'    posXfin = posx + (anccarP - 1)
    posYfin = posY + (altcarP - 1)
    hdc = pic.hdc
    If tipSelec = 1 Then        'Selecci�n por columnas
        pic.Line (posX, posY)-(posX + 1, posYfin), vbRed, B
    Else    'Selecci�n normal
        pic.Line (posX, posY)-(posX + 1, posYfin), mColTxtNor, B
    End If
    curBorrado = False   'marca bandera
    'Actualiza posici�n donde se dibuj� el cursor
    curXt_ant = curXt
    curYt_ant = curYt
End Sub

Public Sub XYCursor(x As Long, y As Long)
'Devuelve coordenadas del cursor en Twips.
    x = anccarP * (curXt - col1 + 1) * Screen.TwipsPerPixelX
    y = altcarP * (curYt - fil1 + 1) * Screen.TwipsPerPixelY
End Sub

Private Sub ActivarCursor()
    cursorOn = True
End Sub

Private Sub DesactivarCursor()
'Desactiva el parpadeo del cursor
    'No lo borra, para no interferir con el m�todo de selecci�n
    cursorOn = False
End Sub

Private Sub ApagCursor()
'Apaga el cursor en la posici�n actual y lo desactiva para parpadeo.
    Call DesactivarCursor
    Call BorCursorXY
End Sub

Public Sub EncenCursor()
'Fuerza a que el cursor aparezca encendido. Activa el parpadeo si es que
'estuviera desactivado
    ActivarCursor       'activa temporizaci�n de cursor
    curtmp = 0  'para mantener encendico el cursor por 500mseg
    'borra el cursor de la posici�n anterior
    Call BorCursorXY
    'Dibuja en la nueva posici�n
    Call DibCursorXY
End Sub

Private Sub Timer1_Timer()
    'Temporiza el parpadeo del cursor
    If Not cursorOn Then Exit Sub
    curtmp = curtmp + 1     'Lleva la cuenta de 250 mseg
    If curtmp >= 2 Then
        curtmp = 0      'para iniciar otra cuenta de 2 pasos
        If curBorrado Then DibCursorXY Else BorCursorXY
    End If
End Sub

Private Function CursorFueraPantalla() As Boolean
'Verifica si el cursor se encuentra fuera de la pantalla visible
    If curYt < fil1 Or curYt > fil2 Or curXt < col1 Or curXt > col2 Then
        CursorFueraPantalla = True
    End If
End Function

Private Sub FijaCol1(valor As Integer)
'Fija un nuevo valor para "col1" y actualiza "col2". S�lo deber�a cambiarse
'"col1" desde este procedimiento. Equivale a un desplazamiento horizontal sin
'mover el cursor. 'No redibuja
    'Verificaciones de validez
    If valor < 1 Then valor = 1
    If valor > MaxCol1() Then valor = MaxCol1()
    'Asignaci�n final
    col1 = valor
    col2 = col1 + maxColVis - 1
End Sub

Private Sub ActualizaNLinFin()
'Recalcula la variable "nFilFin".
'Deber�a llamarse despu�s de cualquier cambio a "fil1" o si se
'eliminan o aumentan lineas visibles en pantalla
    'valor normal de nfilFin
    nfilFin = fil2
    'valor real de nfilFin si hay menos l�neas
    If nfilFin > nlin Then nfilFin = nlin
    'Protecci�n por exceso. Limita hasta donde se mueve la pantalla
    If fil1 > nfilFin Then
        fil1 = nfilFin              'Ajusta pantalla
        If fil1 < 1 Then fil1 = 1   'protecci�n por debajo
        'ha habido modificaci�n de fil1, se debe actualizar fil2
        fil2 = fil1 + maxLinVis - 1
    End If
End Sub

Private Sub FijaFil1(valor As Long)
'Fija un nuevo valor para "fil1" y actualiza "fil2". S�lo deber�a cambiarse
'"fil1" desde este procedimiento Equivale a un desplazamiento vertical sin
'mover el cursor. No redibuja
'Desplaza s�lo en variables. No redibuja
    'verifica validez de desplazamiento
    If valor < 1 Then valor = 1     'limita por arriba
    If valor > nlin Then valor = nlin 'limita
    'Asignaci�n final
    fil1 = valor
    fil2 = fil1 + maxLinVis - 1
    Call ActualizaNLinFin    'aqu� puede cambiar fil1 y fil2
End Sub

Private Sub FijarSel0()
'Fija el punto base de la selecci�n, en el punto actual del cursor
    sel0 = LeePosCur()
    sel1 = sel0         'Selecci�n sigue al cursor
    sel2 = sel0         'Selecci�n sigue al cursor
    sel1ant = sel0      'actualiza anterior
    sel2ant = sel0      'actualiza anterior
End Sub

Private Function LineaEnSel(yt As Long) As Boolean
'Devuelve Verdadero si la linea "yt" est� en el bloque de selecci�n
    If haysel And sel1.yt <= yt And yt <= sel2.yt Then
        LineaEnSel = True
    Else
        LineaEnSel = False
    End If
End Function

'*****************************************************************************
'*************** FUNCIONES PARA MANEJO DE LA MATRIZ DE L�NEAS ****************
'*****************************************************************************
Public Sub LimpiarLineas()
    nlin = 0
    ReDim linrea(0)
    ReDim lincol(0)
    maxTamLin = 1   'Valor inicial
End Sub

Public Property Get linea(i As Long) As String
'Propiedad para devolver el texto de una l�nea
    linea = linrea(i)
End Property

Public Property Get nLinActual() As Long
    nLinActual = curYt
End Property

Public Sub EliminarLineas(pos As Long, nelim As Long)
'Elimina l�neas en la matriz de cadenas, desplazando los elementos
Dim i As Long
    'protecciones
    If pos > nlin Then Exit Sub     'a eliminar desde m�s alla del texto
    If nelim > nlin Then Exit Sub   'a eliminar m�s de lo que hay
    If nelim < 1 Then Exit Sub      'a eliminar negativamente
    'Desplaza elementos
    For i = pos To nlin - nelim
        linrea(i) = linrea(i + nelim)
        lincol(i) = lincol(i + nelim)
    Next
    'Actualiza tama�o
    nlin = nlin - nelim
    ReDim Preserve linrea(nlin)
    ReDim Preserve lincol(nlin)
End Sub

Private Sub InsertarLineas(pos As Long, nins As Long)
'Inserta l�neas, desplazando los elementos. Las l�neas se insertan en blanco.
Dim i As Long
    'protecciones
    If pos > nlin Then Exit Sub
    If nins < 1 Then Exit Sub
    nlin = nlin + nins
    ReDim Preserve linrea(nlin)
    ReDim Preserve lincol(nlin)
    'Desplaza elementos
    For i = nlin To pos + nins Step -1
        linrea(i) = linrea(i - nins)
        lincol(i) = lincol(i - nins)
    Next
End Sub

Private Sub AgregaLinea(lin As String)
'Agrega una l�nea al final en el control de texto
Dim tamexp As Integer
    nlin = UBound(linrea) + 1   'actualiza nuevo n�mero de l�neas
    ReDim Preserve linrea(nlin) 'crea espacio
    ReDim Preserve lincol(nlin) 'crea espacio
    linrea(nlin) = lin      'escribe la nueva l�nea
    'actualiza ancho m�ximo de l�nea
    tamexp = Len(LineaFin(lin))
    If tamexp > maxTamLin Then maxTamLin = tamexp
    Call ActualizaNLinFin   'Para dibujar correctamente
    Call ActLimitesBarDesp  'actualiza l�mites de Scroll Bar's
End Sub

Public Sub ReinicColEdi()
'Reinicia todas las l�neas para que se eval�e de nuevo el color
Dim i As Long
    For i = 1 To UBound(lincol)
        lincol(i).tip = TLIN_DES
    Next
End Sub
'*****************************************************************************
'***************** FUNCIONES PARA MANEJO DE LAS TABULACIONES *****************
'*****************************************************************************

Private Function linexp(i As Long) As String
'Devuelve la l�nea expandida como es v�sible, reemplazando las tabulaciones
    linexp = LineaFin(linrea(i))      'expande los tabs
End Function

Private Function LineaFin(txt As String) As String
'Reemplaza la cadena "txt" a como se debe mostrar (reemplaza tabulaciones)
Dim tmp As String
Dim lin() As String
Dim nesp As Integer
Dim i As Integer
    lin = Split(txt, vbTab)       'corta por tabulaci�nes
    For i = 0 To UBound(lin)
        'completa con espacios
        tmp = tmp & lin(i)           'agrega l�nea
        If i < UBound(lin) Then 'si no es el �ltimo se agrega
            nesp = nEspTab - (Len(lin(i)) Mod nEspTab)  'de 1 a "nEspTab" espacios
            tmp = tmp & String(nesp, " ")   'completa con espacios
        End If
    Next
    LineaFin = tmp
End Function

Private Function posFinTab(x As Integer) As Integer
'Devuelve la posici�n inicial (en caracteres) del siguiente caracter
'que sigue a un caracter de tabulaci�n ubicado en la posici�n x
    posFinTab = nEspTab * ((x - 1) \ nEspTab + 1) + 1
End Function

Private Sub ExplorarTabs(yt As Long)
'Explora la l�nea "yt", y actualiza las matrices:
' * ptabexp() con las posiciones de inicio de las tabulaciones en el texto expandido.
' * ptabrea() con las posiciones de las tabulaciones en el texto real
' Los �ndices de ptabexp() y ptabrea() empiezan en 1
Dim texp As String      'texto expandido
Dim trea As String      'texto real
Dim lin() As String
Dim nesp As Integer
Dim i As Integer
    lin = Split(linrea(yt), vbTab)             'corta por tabulaciones
    If UBound(lin) = -1 Then
        ReDim ptabexp(0)
        ReDim ptabrea(0)
    Else
        ReDim ptabexp(UBound(lin))
        ReDim ptabrea(UBound(lin))
    End If
    For i = 0 To UBound(lin)
        'completa con espacios
        texp = texp & lin(i)                'actualiza l�nea
        trea = trea & lin(i) & " "          'actualiza l�nea
        If i < UBound(lin) Then             'si no es el �ltimo se agrega
            nesp = nEspTab - (Len(lin(i)) Mod nEspTab)  'de 1 a "nEspTab" espacios
            ptabexp(i + 1) = Len(texp) + 1  'guarda posici�n de inicio del tab
            texp = texp & String(nesp, " ") 'completa con espacios
            
            ptabrea(i + 1) = Len(trea)
        End If
    Next
End Sub

Private Function PosXTreal(xt As Integer, yt As Long) As Integer
'Devuelve la posici�n horizontal real xt (en la cadena sin expandir)
'para la fila "yt" , caracter "xt" en el texto expandido
Dim i As Integer
Dim posIni As Integer
Dim posFin As Integer
Dim posSigCar As Integer
Dim distab As Integer
    '--------------Verifica si hay tabulaciones---------------
    PosXTreal = xt    'valor por defecto
    ExplorarTabs yt   'lee posiciones de tabulaci�n
    If UBound(ptabexp) = 0 Then 'Si no hay tabulaciones
        Exit Function   'sale con la misma posici�n
    End If
    '----------------------------------------------------------
    'Hay al menos una tabulaci�n. Verifica en que zona
    'de la cadena cae para buscar su posici�n real
    '----------------------------------------------------------
    'Verifica para la primera zona
    If xt < ptabexp(1) Then
        PosXTreal = xt    'Ocupa la misma posici�n en la cadena real
        Exit Function
    End If
    'Debe estar en las otras zonas
    For i = 1 To UBound(ptabexp)
        'Toma inicio de zona
        posIni = ptabexp(i)
        'Toma fin de zona
        If i < UBound(ptabexp) Then
            posFin = ptabexp(i + 1)
        Else    'Es el tab final
            posFin = Len(linexp(yt)) + 1
        End If
        posSigCar = posFinTab(posIni)
        'Ver si cae en la zon aprohibida de un "tab" en la cadena expandida
        If xt >= posIni And xt < posSigCar Then
            'Est� en la zona de la tabulaci�n expandida
            If xt = posIni Then
                'El cursor est� bien ubicado, se inserta antes
                'de la tabulaci�n
                PosXTreal = ptabrea(i)
                Exit Function
            Else
                'El cursor est� en una posici�n prohibida
                'Puede ser que se est� insertando en modo columnas
                msjError = "Error de ubicaci�n de cursor"
                PosXTreal = ptabrea(i)   'por ahora se ajusta a la izquierda
                Exit Function
            End If
        'Verifica si cae en el texto despu�s del tab
        ElseIf xt >= posSigCar And xt < posFin Then
            distab = xt - posSigCar 'distancia a la tabulaci�n
            PosXTreal = ptabrea(i) + distab + 1
            Exit Function
        End If
    Next
    'S�lo deber�a deber�a llegar aqu� si est� al final
    PosXTreal = Len(linrea(yt)) + 1
End Function

Private Function PosXTexp(xt As Integer, yt As Long) As Integer
'Devuelve la posici�n horizontal xt en la cadena expandida
'para la fila "yt" , caracter "xt" en el texto real
Dim a() As String
Dim lin As String
    '--------------Verifica si hay tabulaciones---------------
    PosXTexp = xt    'valor por defecto
    If xt <= 1 Then Exit Function   'No puede ser de otra forma
    lin = Left$(linrea(yt), xt - 1) 'lee parte afectada de la l�nea
    'La posici�n expandida equivale al largo de la cadena
    'afectada expandida.
    PosXTexp = Len(LineaFin(lin)) + 1
End Function

Public Sub TabToSpaces()
'Convierte tabulaciones a espacios en el editor.
Dim i As Long
    For i = 1 To nlin
        linrea(i) = linexp(i)
    Next
    Call InicDeshacer   'Porque esta acci�n no se puede deshacer
End Sub

'*****************************************************************************
'****************** FUNCIONES PARA DESPLAZAMIENTO DEL CURSOR *****************
'*****************************************************************************

Private Function curSigPal() As Long
'Devuelve la posici�n del cursor "xt" (en coordenadas de texto) de la siguiente
'palabra en la l�nea actual
Dim x As Long
    x = curXt
    If x < 1 Then Exit Function
    'Termina la palabra actual
    While x <= Len(linact) And Mid$(linact, x, 1) Like CAR_DESP_PAL
        x = x + 1
    Wend
    'busca siguiente
    While x <= Len(linact) And Not (Mid$(linact, x, 1) Like CAR_DESP_PAL)
        x = x + 1
    Wend
    curSigPal = x
End Function

Private Function curIniPal() As Long
'Devuelve la posici�n del cursor "xt" de la
'anterior palabra en la l�nea actual
Dim x As Long
    If curXt <= 1 Then Exit Function
    x = curXt
    'busca fin de palabra
    While x > 1 And Not (Mid$(linact, x, 1) Like CAR_DESP_PAL)
        x = x - 1
    Wend
    If x = curXt Then   'ya estaba al inicio de palabra
        x = x - 1   'retrocede
        If x = 0 Then curIniPal = x: Exit Function
        'Busca fin de palabra anterior
        While x > 1 And Not (Mid$(linact, x, 1) Like CAR_DESP_PAL)
            x = x - 1
        Wend
    End If
    'Busca inicio de palabra actual
    While x > 1 And Mid$(linact, x, 1) Like CAR_DESP_PAL
        x = x - 1
    Wend
    If x = 1 Then curIniPal = 1 Else curIniPal = x + 1
End Function

Private Function curIniPal2() As Long
'Devuelve la posici�n del cursor "xt" del
'inicio de palabra en la posici�n actual del cursor
Dim x As Long
    If curXt < 1 Then Exit Function
    x = curXt
    'busca fin de palabra
    If Mid$(linact, x, 1) Like CAR_DESP_PAL Then
        'ya est� en medio de palabra
    Else
        'Hay que buscar el inicio
        If x = 1 Then Exit Function 'es el primero
        x = x - 1   'retrocede
        'Busca fin de palabra anterior
        While x > 1 And Not (Mid$(linact, x, 1) Like CAR_DESP_PAL)
            x = x - 1
        Wend
    End If
    'Busca inicio de palabra actual
    While x > 1 And Mid$(linact, x, 1) Like CAR_DESP_PAL
        x = x - 1
    Wend
    If x = 1 Then curIniPal2 = 1 Else curIniPal2 = x + 1
End Function

Private Function curFinPal() As Long
'Devuelve la posici�n del cursor "xt" del caracter que sigue al
'fin del identificador que se encuentra bajo el cursor
Dim x As Long
    If curXt < 1 Then Exit Function
    x = curXt
    'Busca fin de palabra actual
    While x < Len(linact) + 1 And Mid$(linact, x, 1) Like CAR_DESP_PAL
        x = x + 1
    Wend
    curFinPal = x   'funciona inclusive en el caso l�mite
End Function

Private Function InicioParrafo(yt As Long, xt As Integer) As Boolean
'Indica si una l�nea est� al inicio de un p�rrafo para un valor de xt
    If Len(linexp(yt)) >= xt And Len(linexp(yt - 1)) < xt Then
        InicioParrafo = True
    Else
        InicioParrafo = False
    End If
End Function

Private Function FinalParrafo(yt As Long, xt As Integer) As Boolean
'Indica si una l�nea est� al final de un p�rrafo para un valor de xt
    If yt = nlin Then   'No hay l�nea siguiente
        If Len(linexp(yt)) >= xt Then
            FinalParrafo = True
        Else
            FinalParrafo = False
        End If
    Else                'Hay l�nea siguiente
        If Len(linexp(yt)) >= xt And Len(linexp(yt + 1)) < xt Then
            FinalParrafo = True
        Else
            FinalParrafo = False
        End If
    End If
End Function

Private Function EntreParrafos(yt As Long, xt As Integer) As Boolean
'Indica si una l�nea est� entre dos p�rrafos para un valor de xt
    If Len(linexp(yt)) < xt Then
        EntreParrafos = True
    Else
        EntreParrafos = False
    End If
End Function

Private Function curIniPar() As Long
'Devuelve la posici�n del cursor "yT" (en coordenadas del texto) del inicio
'del parrafo en la posici�n actual del cursor o del fin del p�rrafo anterior
Dim y As Long
    If curYt = 1 Then Exit Function
    y = curYt
    'Verifica si est� al inicio de un p�rrafo
    If InicioParrafo(y, curXt) Then
        'Buscar� el fin del p�rrafo anterior
        y = y - 1
        'Busca fin de p�rrafo anterior
        While y > 1 And Len(linexp(y)) < curXt
            y = y - 1
        Wend
        curIniPar = y
        Exit Function   'sale
    End If
    'Si est� entre p�rrafos se mueve hasta el fin del anterior
    If EntreParrafos(y, curXt) Then
        While y > 1 And Len(linexp(y)) < curXt
            y = y - 1
        Wend
        curIniPar = y
        Exit Function   'sale
    End If
    'Busca inicio de p�rrafo actual
    While y > 1 And Len(linexp(y)) >= curXt
        y = y - 1
    Wend
    If y = 1 Then        'lleg� al inicio
        curIniPar = y
    Else    'encontr� l�mite
        y = y + 1
        curIniPar = y
    End If
End Function

Private Function curFinPar() As Long
'Devuelve la posici�n del cursor "yt" (en coordenadas del texto) del fin
'del parrafo en la posici�n actual del cursor o del inicio del p�rrafo siguiente
Dim y As Long
    If curYt = nlin Then curFinPar = curYt: Exit Function
    y = curYt
    'Verifica si est� al final de un p�rrafo
    If FinalParrafo(y, curXt) Then
        'Buscar� el inicio del p�rrafo siguiente
        y = y + 1
        'Busca fin de p�rrafo anterior
        While y < nlin And Len(linexp(y)) < curXt
            y = y + 1
        Wend
        curFinPar = y
        Exit Function   'sale
    End If
    'Si est� entre p�rrafos se mueve hasta el inicio del siguiente
    If EntreParrafos(y, curXt) Then
        While y < nlin And Len(linexp(y)) < curXt
            y = y + 1
        Wend
        curFinPar = y
        Exit Function   'sale
    End If
    'Busca fin de p�rrafo actual
    While y < nlin And Len(linexp(y)) >= curXt
        y = y + 1
    Wend
    If Not FinalParrafo(y, curXt) Then        'al inicio
        y = y - 1
    End If
    curFinPar = y
End Function

Public Property Let Text(ByRef txt As String)
'Actualiza el contenido del CONTROL
Dim a() As String
Dim i As Integer
    'inicia contenido en 0 l�neas
    Call LimpiarLineas
    If txt <> "" Then
        'asignar texto
        a = Split(txt, vbCrLf)
        For i = 0 To UBound(a)
            AgregaLinea a(i)
        Next
    End If
    Call ActualizaNLinFin   'actualiza l�neas visibles
    Call ActLimitesBarDesp  'actualiza l�mites de Scroll Bar's
    'posici�n inicial del cursor
    tCursorA2 maxTamLin, nlin
    Call Dibujar
End Property

Public Property Get Text() As String
'Devuelve el contenido del control
'Devuelve el texto seleccionado.
Dim tip0 As Integer
    tip0 = tipSelec 'guarda tipo de seleccion
    tipSelec = 0    'pone en modo normal para copiar todo
    Text = TextBlo(MinPos, MaxPos)
    tipSelec = tip0 'Restaura tipo de seleccion
End Property

'*****************************************************************************
'******************** FUNCIONES PARA MANEJO DE BLOQUES ***********************
'*****************************************************************************
Private Function LeePosCur() As Tpostex
'Lee la posici�n actual de cursor en la variable de posici�n pos
    LeePosCur.xt = curXt
    LeePosCur.yt = curYt
End Function

Private Function PosNulo(p As Tpostex) As Boolean
'Indica si una posici�n no ha sido iniciada
    PosNulo = (p.xt = 0)
End Function

Private Function MinPos() As Tpostex
'Devuelve la posici�n menor del texto en el editor
    If nlin > 0 Then
        MinPos.xt = 1
        MinPos.yt = 1
    End If
End Function

Private Function MaxPos() As Tpostex
'Devuelve la posici�n mayor del texto en el editor
    MaxPos.yt = nlin
    If nlin > 0 Then
        MaxPos.xt = Len(linexp(nlin)) + 1
    End If
End Function

Private Function TextPosIni(p1 As Tpostex) As String
'Devuelve la primera l�nea del bloque que empieza en la posici�n p1.
'S�lo debe usarse cuando el bloque tiene m�s de una l�nea
'Devuelve texto sin expandir
Dim x1r As Integer, y1 As Long
    y1 = p1.yt
    x1r = PosXTreal(p1.xt, y1)
    TextPosIni = Mid$(linrea(y1), x1r)       'copia primera l�nea
End Function

Private Function TextPosFin(p2 As Tpostex) As String
'Devuelve la �ltima l�nea del bloque que termina en la posici�n p2.
'S�lo debe usarse cuando el bloque tiene m�s de una l�nea
'Devuelve texto sin expandir
Dim x2r As Integer, y2 As Long
    y2 = p2.yt
    x2r = PosXTreal(p2.xt, y2)
    TextPosFin = Mid$(linrea(y2), 1, x2r - 1)  'copia �ltima l�nea
End Function

Private Function TextPosLin(p1 As Tpostex, p2 As Tpostex) As String
'Devuelve el texto seleccionado del bloque p1-p2.
'S�lo debe usarse cuando el bloque est� en una sola l�nea.
'Devuelve texto sin expandir
Dim y1 As Long
Dim x1r As Integer, x2r As Integer
    y1 = p1.yt      'igual a p2.yt
    x1r = PosXTreal(p1.xt, y1)
    x2r = PosXTreal(p2.xt, y1)
    TextPosLin = Mid$(linrea(y1), x1r, x2r - x1r)  'copia l�nea
End Function

Private Function TextPosCol(yt As Long, xt1 As Integer, xt2 As Integer) As String
'Devuelve el texto intermedio de una l�nea en el modo columna
'Para extraer el texto intermedio, se expanden primero las tabulaciones
'y se completan con expacios si la l�nea es muy peque�a.
'xt1 DEBE SER SIEMPRE menor o igual a xt2
Dim x1 As Integer
Dim x2 As Integer
Dim txt As String
    txt = linexp(yt)    'expande las tabulaciones
    If Len(txt) < xt1 Then   'l�nea muy peque�a
        TextPosCol = String(xt2 - xt1, " ")  'devuelve espacios
    ElseIf Len(txt) < xt2 - 1 Then 's�lo se ve parcialmente
        TextPosCol = Mid$(txt & String(xt2 - 1 - Len(txt), " "), xt1)
    Else    'La l�nea es suficientemente grande
        TextPosCol = Mid$(txt, xt1, xt2 - xt1)
    End If
End Function

Private Function TamPosBlo(p1 As Tpostex, p2 As Tpostex) As Long
'Devuelve el tama�o de un bloque en bytes. Es eficiente a�n con bloques grandes
'Toma en cuenta el tipo de selecci�n actual
'Para el caso de selecci�n por columnas, se considera el texto expandido.
'Para el caso de selecci�n normal se da el tama�o del texto sin expandir
Dim tam As Long
Dim i As Long
    If UBound(linrea) = 0 Then tam = 0: Exit Function
    If tipSelec = 1 Then        'Selecci�n por columnas
        'Para el c�lculo, se fija un tama�o uniforme de selecci�n
        tam = Abs(p1.xt - p2.xt) + 2  'caracteres por l�nea m�s el salto de l�nea
        i = (p2.yt - p1.yt + 1)   'n�mero de l�neas
        TamPosBlo = tam * i - 2        'quita el salto final
        Exit Function
    End If
    'Selecci�n por filas
    If p1.yt = p2.yt Then   'Bloque en una sola l�nea
        tam = Len(TextPosLin(p1, p2))
    Else                    'Bloque en varias l�neas
        tam = Len(TextPosIni(p1))            'tama�o primera l�nea
        For i = p1.yt + 1 To p2.yt - 1
            tam = tam + 2 + Len(linrea(i))   'considera 2 caracteres del salto
        Next
        tam = tam + 2 + Len(TextPosFin(p2))  'tama�o �ltima l�nea
    End If
    TamPosBlo = tam   'Devuelve
End Function

Private Function BloAMem(tam As Long, p1 As Tpostex, p2 As Tpostex) As Long
'Funcion estrella del programa. Se usa para las opciones del portapapeles y
'para la funcionalidad de "deshacer".
'Hace un volcado r�pido de un bloque de texto a Memoria.
'Puede trabajar �ficientemente con varios miles de l�neas.
'Si hubo error en asignar memoria devuelve 0, de otra forma devuelve el
'manejador del bloque de memoria.
'Actualiza la variable "tam" con el tama�o del bloque reservado
Dim nbytes As Long  'N�mero de bytes escritos
Dim f As Long
Dim lpMemory As Long
Dim retval As Long
Dim hData As Long   'Manejador de memoria
Dim cad As String   'Cadena a escribir
Dim xt1 As Integer, xt2 As Integer
Dim xtmp As Integer
    '-----------Copia datos a memoria - Metodo1----------
    'Calcula el tama�o total del bloque
    tam = TamPosBlo(p1, p2)
    'Asigna espacio en memoria. Es tam+1 porque se le agregar� un NULL a la cadena
    hData = GlobalAlloc(GMEM_MOVEABLE Or GMEM_DDESHARE, tam + 1)
    If hData = 0 Then   'No se pudo encontrar memoria
        BloAMem = 0
        Exit Function
    End If
    'Copiamos la cadena al espacio de memoria reservada
    lpMemory = GlobalLock(hData)    'bloquea mientras copia y obtenemos direcci�n
    If tipSelec = 1 Then        'Selecci�n por columnas
        'Lee coordenadas horizontales
        xt1 = p1.xt: xt2 = p2.xt
        If xt1 > xt2 Then   'Verifica si hay que invertir
            xtmp = xt1: xt1 = xt2: xt2 = xtmp
        End If
        cad = TextPosCol(p1.yt, xt1, xt2) 'Lee parte inicial del bloque
        nbytes = Len(cad)       'tama�o sin incluir el NULL final
        retval = lstrcpy(lpMemory, cad)     'Copia incluyendo el NULL final
        lpMemory = lpMemory + nbytes        'apunta al NULL final escrito
        For f = p1.yt + 1 To p2.yt
            cad = vbCrLf & TextPosCol(f, xt1, xt2)
            nbytes = Len(cad)       'tama�o sin incluir el NULL final
            retval = lstrcpy(lpMemory, cad) 'Copia incluyendo el NULL final
            lpMemory = lpMemory + nbytes    'apunta al NULL final escrito
        Next
    Else    'Selecci�n normal
        If p1.yt = p2.yt Then   'Selecci�n de una sola l�nea
            'Copia incluyendo el NULL final
            retval = lstrcpy(lpMemory, TextPosLin(p1, p2))
        Else
            'Selecci�n de varias l�neas
            cad = TextPosIni(p1)        'Lee parte inicial del bloque
            nbytes = Len(cad)           'tama�o sin incluir el NULL final
            retval = lstrcpy(lpMemory, cad)     'Copia incluyendo el NULL final
            lpMemory = lpMemory + nbytes        'apunta al NULL final escrito
            For f = p1.yt + 1 To p2.yt - 1
                cad = vbCrLf & linrea(f)
                nbytes = Len(cad)       'tama�o sin incluir el NULL final
                retval = lstrcpy(lpMemory, cad) 'Copia incluyendo el NULL final
                lpMemory = lpMemory + nbytes    'apunta al NULL final escrito
            Next
            cad = vbCrLf & TextPosFin(p2)       'Lee parte final del bloque
            retval = lstrcpy(lpMemory, cad)     'Copia incluyendo el NULL final
        End If
    End If
    Call GlobalUnlock(hData)            'desbloquea
    BloAMem = hData     'Devuelve manejador
End Function

Private Property Get TextBlo(p1 As Tpostex, p2 As Tpostex) As String
'Devuelve el texto de un bloque.
Dim hData As Long   'Manejador de memoria
Dim lpMemory As Long
Dim nbytes As Long
    'Protecci�n
    If p1.xt = p2.xt And p1.yt = p2.yt Then Exit Sub
    'Copia bloque a memoria
    hData = BloAMem(nbytes, p1, p2) 'Copia selecci�n a memoria
    If hData = 0 Then
        MsgBox "No se puede obtener selecci�n. Error asignando memoria", vbCritical
        Exit Property
    End If
    TextBlo = Space(nbytes + 1)     'crea espacio para contener a la cadena y el NULL
    lpMemory = GlobalLock(hData)    'bloquea mientras copia y obtenemos direcci�n
    lstrcpy TextBlo, lpMemory        'Copia r�pidamente a cadena
    Call GlobalUnlock(hData)        'desbloquea
    TextBlo = Left(TextBlo, Len(TextBlo) - 1)    'Quita NULL final
    GlobalFree hData
    Exit Property

'No se usa el m�todo:
'        For i = .yt To  .yt
'            tmp = tmp & vbCrLf & linrea(i)
'        Next
'Porque es muy lento cuando hay muchas l�neas
End Property

Public Property Get TextSel() As String
'Devuelve el texto seleccionado.
    If Not haysel Then Exit Property
    TextSel = TextBlo(sel1, sel2)
End Property

'*****************************************************************************
'******************** FUNCIONES DE POSICIONAMIENTO DE CURSOR *****************
'*****************************************************************************

Private Sub AjustaPantalla()
'Ajusta las coordenadas de la pantalla para que sea visible el cursor
'No modifica nada en el caso que el cursor sea visible.
'Actualiza las variables globales "curXt", "curYt"
    'Ubica horizontal
    If curXt < col1 Then
        FijaCol1 curXt
        curXt = col1
    End If
    If curXt > col2 Then
        FijaCol1 curXt - maxColVis + 1
        curXt = col2
    End If
    'Ubica vertical
    If curYt < fil1 Then
        FijaFil1 curYt
        curYt = fil1
    End If
    If curYt > fil2 Then
        FijaFil1 curYt - maxLinVis + 1   'desplaza
        curYt = fil2    'debe actualizarse tambi�n
    End If
End Sub

Private Sub FijaCursor(ByVal xt As Integer, ByVal yt As Long, _
            Optional ajus_hor As Integer = A_NULO)
'Fija el cursor en la posici�n xc, yc.
'S�lo permite poner el cursor en una zona v�lida del texto (aunque no sea
'visible en la pantalla actual). Si cae fuera del texto lo ajusta a caer dentro.
'No hace desplazamiento de pantalla.
'Actualiza las variables globales "curXt", "curYt" y "linact"
''"ajus_hor" es el ajuste que se desea realizar, puede ser:
'A_NULO ->     Sin ajuste. Puede aparecer en medio de la zona del tab
'A_IZQ_TAB ->  A izquierda cuando hay tabulaci�n
'A_DER_TAB ->  A derecha cuando hay tabulaci�n
Dim i As Integer
Dim posSigCar As Integer
    '-----Verifica si hay l�neas en el control
    If nlin = 0 Then    'no hace nada, s�lo posiciona
        curXt = 1: curYt = 1
        linact = ""
        Exit Sub
    End If
    '-----valida que caiga en una zona v�lida del texto
    'calcula y valida "curYt"
    curYt = yt                     'valor inicial
    If curYt < 1 Then curYt = 1    'valida por abajo
    If curYt > nlin Then curYt = nlin  'valida por arriba
    linact = linexp(curYt)          'actualiza l�nea actual
    If Len(linact) > maxTamLin Then
        maxTamLin = Len(linact)     'es la l�nea mayor
        Call ActLimitesBarDesp      'actualiza barra
    End If
    'calcula y valida "curXt"
    If CLng(xt) > 32767 Then xt = col1  'protecci�n
    curXt = xt                      'valor inicial
    If curXt < 1 Then curXt = 1     'valida por abajo
    If curXt > Len(linact) + 1 Then curXt = Len(linact) + 1 'valida por arriba
    '----Realiza los ajustes si se han pedido.
    If ajus_hor <> A_NULO Then  'Hay que realizar ajustes
        'Verifica si cae en posici�n prohibida por haber tabulaci�n
        ExplorarTabs curYt  'lee posiciones de tabulaci�n
        For i = 1 To UBound(ptabexp)
            'Verifica si cae en la zona prohibida definida por un "tab"
            posSigCar = posFinTab(ptabexp(i))
            If curXt > ptabexp(i) And curXt < posSigCar Then
                If ajus_hor = A_DER_TAB Then
                    curXt = posSigCar   'actualiza "curXt"
                End If
                If ajus_hor = A_IZQ_TAB Then
                    curXt = ptabexp(i)    'actualiza "curXt"
                End If
            End If
        Next
    End If
End Sub

Private Sub tCursorA(xt As Integer, yt As Long, Optional ajus_hor As Integer = A_IZQ_TAB)
'Funci�n similar a FijaCursor(), pero realiza el desplazamiento de
'la pantalla cuando sea necesario para que el cursor siempre aparezca visible
'Actualiza la bandera "Redibujar", cuando se requiere dibujar toda la pantalla.
    FijaCursor xt, yt, ajus_hor      'mueve el cursor
    'verifica si es necesario refrescar la pantalla
    If CursorFueraPantalla Then
        Call AjustaPantalla
        Redibujar = True    'pide que se redibuje
    End If
End Sub

Private Sub tCursorA2(xt As Integer, yt As Long, Optional ajus_hor As Integer = A_IZQ_TAB)
'Versi�n de tCursorA() que verifica si el cursor queda en una posici�n
'horizontal l�mite y encuadra la pantalla para que se vea mejor.
'Actualiza la bandera "Redibujar", cuando se requiere dibujar toda la pantalla.
    FijaCursor xt, yt, ajus_hor
    'Verifica si el cursor cae en una zona no visible de la pantalla
    If CursorFueraPantalla Then
        AjustaPantalla
        'Verifica si qued� al final de l�nea
        If curXt = col2 Then
            FijaCol1 col1 + 12
            AjustaPantalla   'porque puede que se haya ocultado el cursor
                             'y para actualizar curXt
        End If
        'Verifica si cae al inicio
        If curXt = col1 Then
            FijaCol1 col1 - 12  'Intenta desplazar
            AjustaPantalla   'porque puede que se haya ocultado el cursor
                             'y para actualizar curXt
        End If
        Redibujar = True
    End If
End Sub

Private Sub posCursorA(pos As Tpostex, Optional ajus_hor As Integer = A_IZQ_TAB)
'Versi�n de tCursorA(), pero acepta una posici�n de tipo "Tpostex"
    tCursorA pos.xt, pos.yt, ajus_hor
End Sub

Private Sub posCursorA2(pos As Tpostex, Optional ajus_hor As Integer = A_IZQ_TAB)
'Versi�n de tCursorA2(), pero acepta una posici�n de tipo "Tpostex"
    tCursorA2 pos.xt, pos.yt, ajus_hor
End Sub

Public Sub CursorText(xt As Integer, yt As Long)
'Funci�n p�blica para fijar la posici�n del cursor
    Redibujar = False
    tCursorA2 maxTamLin + 1, nlin, A_IZQ_TAB    'para encuadrar desde arriba
    Call tCursorA2(xt, yt)
    curXd = curXt     'actualiza posici�n deseada
    Call LimpSelec(True)      'Limpia selecci�n
    'Marca la posici�n del cursor antes de una selecci�n
    Call FijarSel0      'Fija punto base
    Call EncenCursor    'Enciende para que sea visible en la nueva posici�n
    If Redibujar Then Call Refrescar
End Sub

Public Sub SelectHasta(xt As Integer, yt As Long)
'Funci�n p�blica para fijar el fin de una selecci�n. Se debe habe definido el inicio
'con CursorText
    tCursorA2 xt, yt
    Call ExtenderSel 'Extiende selecci�n
End Sub
'*****************************************************************************
'******************** FUNCIONES DE DIBUJO DEL TEXTO  *****************
'*****************************************************************************

Private Sub LeerXPosSel(x1 As Long, x2 As Long)
'Devuelve las coordenadas horizontales x1 y x2 del bloque de selecci�n
'a mostrar en pantalla. Devuelve en de pixeles
    'Calcula posici�n horizontal de inicio y fin de bloque
    x1 = (sel1.xt - col1) * anccarP
    If x1 < 0 Then x1 = 0
    If x1 > ScaleWidth Then x1 = ScaleWidth
    x2 = (sel2.xt - col1) * anccarP - 1   'incluye s�lo el recuadro del caracter no el siguiente
    If x2 < 0 Then x2 = 0
    If x2 > ScaleWidth Then x2 = ScaleWidth
End Sub

Private Sub LeerXCurSel(xc1 As Integer, xc2 As Integer)
'Devuelve las coordenadas horizontales xc1 y xc2 del bloque de selecci�n
'a mostrar en pantalla. Devuelve en coordenadas de Cursor.
'xc1 es la posici�n del caracter en la l�nea donde se inicia la selecci�n y
'xc2 es la posici�n del caracter en la l�nea donde termina la selecci�n.
    'Calcula posici�n horizontal de inicio y fin de bloque
    xc1 = sel1.xt - col1 + 1
    If xc1 < 1 Then xc1 = 1
    If xc1 > maxColVis Then
        xc1 = maxColVis
    End If
    xc2 = sel2.xt - col1 + 1  'incluye s�lo el recuadro del caracter no el siguiente
    If xc2 < 1 Then xc2 = 1
    If xc2 > maxColVis Then
        xc2 = maxColVis
    End If
End Sub

Private Sub DibBloFonC(yc As Long, xc1 As Integer, xc2 As Integer, col_fon As Long)
'Dibuja un recuadro relleno con color "col_fon". Las coordenadas son de cursor
Dim xp1 As Long, xp2 As Long
Dim yp As Long
    'Valida par�metros
'    If xc2 < 1 Then Exit Sub
'    If xc1 < maxColVis Then Exit Sub
    If xc1 < 1 Then xc1 = 1
    If xc2 > maxColVis + 1 Then xc2 = maxColVis + 1
    'Convierte a pixeles
    xp1 = (xc1 - 1) * anccarP '+ ancNLinP
    xp2 = (xc2 - 1) * anccarP '+ ancNLinP
    yp = (yc - 1) * altcarP 'actualiza coordenada vertical
    FijaRelleno col_fon
    FijaLapiz PS_SOLID, 1, col_fon
    If xp2 = xp1 Then xp2 = xp2 + 2     'para que sea visible la selecci�n de 0 columnas
    Rectangle pic.hdc, xp1, yp, xp2, yp + altcarP
End Sub

Private Sub cierraSegm(lin() As TDesSeg, i As Integer, _
                       pfin As Long, col As Long, tip As Integer)
'Cierra un segmento de texto y actualiza "pfin".
'"n" es el tama�o actual de la matriz. El segmento a cerrar llega hasta "i-1"
'"pfin" es la posici�n de fin del bloque anterior
Dim n As Integer
    If i > pfin + 1 Then  'hay segmento antes?
        n = UBound(lin) + 1
        ReDim Preserve lin(n)
        lin(n).tam = i - pfin - 1
        pfin = i - 1  'actualiza el limite
        lin(n).col = col    'texto normal
        lin(n).tip = tip    'asigna tipo
    End If
End Sub

Private Sub cierraSegm1(lin() As TDesSeg, i As Integer, _
                        pfin As Long, col As Long, tip As Integer)
'Similar a cierraSegm() pero considera que el segmento llega hasta "i"
Dim n As Integer
    If i > pfin + 1 Then   'hay segmento antes?
        n = UBound(lin) + 1
        ReDim Preserve lin(n)
        lin(n).tam = i - pfin
        pfin = i   'actualiza el limite
        lin(n).col = col    'color de texto
        lin(n).tip = tip    'asigna tipo
    End If
End Sub

Private Function cierraSegmId(lin() As TDesSeg, i As Integer, _
                       pfin As Long, col As Long, tip As Integer, _
                       tmp As String, iden As String, largo As Integer) As Boolean
'Cierra un segmento y crea uno nuevo, basado siempre que se encuentre
'un identificador en la cadena "tmp" a partir de la posici�n "i".
    If Mid$(tmp, i, largo) = iden And Not (Mid$(tmp, i + largo, 1) Like CAR_IDEN_VALM) Then
        cierraSegm lin(), i, pfin, col, tip   'cierra anterior
        i = i + largo - 1   'adelanta el �ndice, se adelantar� 1 en el "for"
        'crea segmento de palabra reservada
        cierraSegm1 lin(), i, pfin, mColPalRes, TSEG_PRS
        
        cierraSegmId = True 'indica que se encontr� segmento
    Else
        cierraSegmId = False
    End If
End Function

Private Function cierraSegmId2(lin() As TDesSeg, i As Integer, _
                       pfin As Long, col As Long, tip As Integer, _
                       tmp As String, iden As String, largo As Integer) As Boolean
'Igual a "cierraSegmId", pero para el segundo grupo de palabras reservadas
    If Mid$(tmp, i, largo) = iden And Not (Mid$(tmp, i + largo, 1) Like CAR_IDEN_VALM) Then
        cierraSegm lin(), i, pfin, col, tip   'cierra anterior
        i = i + largo - 1   'adelanta el �ndice, se adelantar� 1 en el "for"
        'crea segmento de palabra reservada
        cierraSegm1 lin(), i, pfin, mColPalRes2, TSEG_PRS2
        
        cierraSegmId2 = True 'indica que se encontr� segmento
    Else
        cierraSegmId2 = False
    End If
End Function

Private Sub AnalizarIdentificador(c As String, tmp As String, _
                        lin() As TDesSeg, i As Integer, _
                        pfin As Long, colseg As Long, tipseg As Integer)
'Analiza los identificadores en busca de palabras reservadas
    Select Case c
    Case "A"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "ALUMINIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "ANTIMONIO", 9) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "AMERICIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "AZUFRE", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "B"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "BARIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "BERKELIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "BERILIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "BORO", 4) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "C"
        If cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "CADMIO", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "CALCIO", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "CARBONO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "CLORO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "E"
        If cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "ERBIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "ESTA�O", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "F"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "FLUOR", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "F�SFORO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "H"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "HELIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "HIDR�GENO", 9) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "HIERRO", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "I"
        If cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "INDIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "ITERBIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "ITRIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "L"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "LITIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "LUTECIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "M"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "MAGNESIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "MERCURIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "MOLIBDENO", 9) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "N"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "NE�N", 4) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "NITR�GENO", 9) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "O"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "ORO", 3) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "OX�GENO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "P"
        If cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "PALADIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "PLATA", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "PLATINO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "PLOMO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "PLUTONIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "R"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "RADIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "RAD�N", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "S"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "SELENIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "SILICIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "SODIO", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "T"
        If cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "TANTALIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId2(lin(), i, pfin, colseg, tipseg, tmp, "TECNECIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "TITANIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "TUNGSTENO", 9) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "U"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "URANIO", 6) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "V"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "VANADIO", 7) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "X"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "XEN�N", 5) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    Case "Z"
        If cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "ZINC", 4) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        ElseIf cierraSegmId(lin(), i, pfin, colseg, tipseg, tmp, "ZIRCONIO", 8) Then
            tipseg = TSEG_DES    'prepara tipo siguiente
        End If
    End Select

End Sub

Private Sub ActualDescColFil(txt As String, lin() As TDesSeg)
'Actualiza el vector descriptor de segmentos de una fila.
'Sirve para facilitar el an�lisis sem�ntico y el coloreado de sintaxis.
'S�lo soporta filas menores a 32767 caracteres
Dim pfin As Long  'posici�n de fin de bloque
Dim i As Integer, n As Integer
Dim colseg As Long      'color de segmento
Dim tipseg As Integer   'tipo de segmento
Dim buscafincad1 As Boolean
Dim buscafincad2 As Boolean
Dim c As String, tmp As String
Dim IniIden As Boolean  'bandera de inicio de identificador
    'n = 0   'n�mero de elementos de la matriz
    ReDim lin(0)
    If txt = "" Then Exit Sub
    colseg = mColTxtNor    'inicia color de segmento
    tipseg = TSEG_NOR
    pfin = 0    'Posici�n del caracter final del bloque
    tmp = UCase(txt)    'La comparaci�n se hace ignorando la caja
    
    IniIden = True      'El inicio de la l�nea es inicio de identificador
    For i = 1 To Len(txt)
        c = Mid$(tmp, i, 1)    'caracter i
        If buscafincad1 Then   'Estamos dentro de una constante de cadena
            If c = """" Then
                'se toma hasta i para incluir las comillas
                cierraSegm1 lin(), i, pfin, mColTxtCad, TSEG_CAD   'cierra
                buscafincad1 = False     'Marca fin de constante cadena
            End If
        ElseIf buscafincad2 Then   'Estamos dentro de una constante de cadena
            If c = "'" Then
                'se toma hasta i para incluir las comillas
                cierraSegm1 lin(), i, pfin, mColTxtCad, TSEG_CAD   'cierra
                buscafincad2 = False     'Marca fin de constante cadena
            End If
        ElseIf Mid$(tmp, i, 2) = "--" Then  'Busca comentario
            cierraSegm lin(), i, pfin, colseg, tipseg     'cierra anterior
            'crea segmento final
            n = UBound(lin) + 1
            ReDim Preserve lin(n)
            lin(n).tam = Len(txt) - pfin
            lin(n).col = mColTxtCom    'comentario
            lin(n).tip = TSEG_COM
            Exit Sub    'Ya no hay m�s segmentos despu�s de este
        ElseIf c = """" Then      'Busca comilla
            cierraSegm lin(), i, pfin, colseg, tipseg   'cierra anterior
            buscafincad1 = True  'marca bandera
        ElseIf c = "'" Then      'Busca comilla
            cierraSegm lin(), i, pfin, colseg, tipseg  'cierra anterior
            buscafincad2 = True   'marca bandera
        'busca palabras reservadas
        ElseIf IniIden Then     'Es el inicio de identificador (palabras reservadas)
            AnalizarIdentificador c, tmp, lin(), i, pfin, colseg, tipseg
        End If
        'Valida estado de "IniIden" para el siguiente caracter
        If c Like CAR_IDEN_VALM Then IniIden = False Else IniIden = True
    Next
    'Termin� la exploraci�n, cierra segmento
    If buscafincad1 Then
        'Cadena sin delimitador final
        cierraSegm1 lin(), i, pfin, mColTxtCad, TSEG_NOR     'cierra
    ElseIf buscafincad2 Then
        'Cadena sin delimitador final
        cierraSegm1 lin(), i, pfin, mColTxtCad, TSEG_NOR     'cierra
    Else
        cierraSegm lin(), i, pfin, colseg, tipseg
    End If
End Sub

Private Sub DibLinSel(y As Long, yc As Long, yt As Long, linvis As String)
'Dibuja una l�nea de texto en modo BN.
'La l�nea a dibujar debe est�r en el bloque se selecci�n
Dim xc1 As Integer, xc2 As Integer
Dim tmp As String
    'Dibuja el fondo con la selecci�n
    LeerXCurSel xc1, xc2    'obtiene coordenadas de selecci�n
    If tipSelec = 1 Then    '--------Selecci�n por columnas
        'Dibuja el texto antes del bloque
        pic.ForeColor = mColTxtNor
        tmp = Left$(linvis, xc1 - 1)    'protege de l�neas peque�as
        TextOut pic.hdc, 0, y, tmp, Len(tmp)
        'Dibuja el texto despu�s del bloque
        tmp = Mid$(linvis, xc2)         'protege de l�neas peque�as
        TextOut pic.hdc, (xc2 - 1) * anccarP, y, tmp, Len(tmp)
        'Dibuja fondo de selecci�n
        Call DibBloFonC(yc, xc1, xc2, mColFonSel)
        'Dibuja texto seleccionado
        pic.ForeColor = mColTxtSel
        If xc2 > xc1 Then   'Verificaci�n de la menor corrdenada
            tmp = Mid$(linvis, xc1, xc2 - xc1)       'protege de l�neas peque�as
            TextOut pic.hdc, (xc1 - 1) * anccarP, y, tmp, Len(tmp)
        Else
            tmp = Mid$(linvis, xc2, xc1 - xc2)       'protege de l�neas peque�as
            TextOut pic.hdc, (xc2 - 1) * anccarP, y, tmp, Len(tmp)
        End If
    Else                    '--------Selecci�n normal
        'Dibuja el fondo,
        If yt = sel1.yt And yt = sel2.yt Then '�nica l�nea con la selecci�n
            'Dibuja el texto antes del bloque
            pic.ForeColor = mColTxtNor
            tmp = Left$(linvis, xc1 - 1)    'protege de l�neas peque�as
            TextOut pic.hdc, 0, y, tmp, Len(tmp)
            'Dibuja el texto despu�s del bloque
            tmp = Mid$(linvis, xc2)         'protege de l�neas peque�as
            TextOut pic.hdc, (xc2 - 1) * anccarP, y, tmp, Len(tmp)
            'Dibuja fondo de selecci�n
            Call DibBloFonC(yc, xc1, xc2, mColFonSel)
            'Dibuja texto seleccionado
            pic.ForeColor = mColTxtSel
            tmp = Mid$(linvis, xc1, xc2 - xc1)       'protege de l�neas peque�as
            TextOut pic.hdc, (xc1 - 1) * anccarP, y, tmp, Len(tmp)
        ElseIf yt = sel1.yt Then    'primera l�nea de la seleci�n
            'Dibuja el texto antes del bloque
            pic.ForeColor = mColTxtNor
            tmp = Left$(linvis, xc1 - 1)    'protege de l�neas peque�as
            TextOut pic.hdc, 0, y, tmp, Len(tmp)
            'Dibuja fondo de selecci�n
            xc2 = Len(linvis) + 1   'selecciona hasta el final
            xc2 = xc2 + 1           'un caracter m�s para indicar que la selecci�n va hasta el final
            Call DibBloFonC(yc, xc1, xc2, mColFonSel)
            'Dibuja texto seleccionado
            pic.ForeColor = mColTxtSel
            tmp = Mid$(linvis, xc1)       'protege de l�neas peque�as
            TextOut pic.hdc, (xc1 - 1) * anccarP, y, tmp, Len(tmp)
        ElseIf yt = sel2.yt Then    '�ltima l�nea de la seleci�n
            'Dibuja el texto despu�s del bloque
            pic.ForeColor = mColTxtNor
            tmp = Mid$(linvis, xc2)         'protege de l�neas peque�as
            TextOut pic.hdc, (xc2 - 1) * anccarP, y, tmp, Len(tmp)
            'Dibuja fondo de selecci�n
            xc1 = 1                 'selecciona desde el inicio
            Call DibBloFonC(yc, xc1, xc2, mColFonSel)  'fondo de selecci�n
            'Dibuja texto seleccionado
            pic.ForeColor = mColTxtSel
            tmp = Mid$(linvis, 1, xc2 - 1)          'protege de l�neas peque�as
            TextOut pic.hdc, 0, y, tmp, Len(tmp)
        ElseIf yt > sel1.yt And yt < sel2.yt Then   'l�nea completamente seleccionada
            'Dibuja fondo de selecci�n
            xc1 = 1                 'selecciona desde el inicio
            xc2 = Len(linvis) + 1   'selecciona hasta el final
            xc2 = xc2 + 1   'un caracter m�s para indicar que la selecci�n va hasta el final
            Call DibBloFonC(yc, xc1, xc2, mColFonSel)
            'Dibuja texto seleccionado
            pic.ForeColor = mColTxtSel
            TextOut pic.hdc, 0, y, linvis, Len(linvis)
        Else
            'Aqu� significa que la l�nea no est� en la zona de selecci�n
            'Nunca deber�a darse esta condici�n, si se verifica antes de
            'llamar a esta rutina
        End If
    End If
End Sub

Private Sub DibujaLinBN(yt As Long, Optional BorraFondo As Boolean = True)
'Refresca una l�nea completa que est� en la posici�n indicada en coordenadas
'de texto (1..nLin). Por defecto borra el fondo antes de dibujar el texto.
'Dibuja el texto considerando la zona seleccionada.
'El texto se dibuja siempre empezando en la coordenada x=0.
Dim y As Long
Dim yc As Long
Dim linvis As String
Dim lin As String
    'Verifica si escapa del texto
    If yt < 1 Or yt > nlin Then Exit Sub
    yc = yt - fil1 + 1   'Coord. de cursor
    If yc < 1 Or yc > maxLinVis Then Exit Sub   'fuera de pantalla
    'toma l�nea afectada
    linvis = Mid(linexp(yt), col1, maxColVis)
    y = (yt - fil1) * altcarP    'posici�n vertical en pixels
    'Dibuja fondo de l�nea
    If BorraFondo Then Call DibBloFonC(yc, 1, maxColVis + 1, mColFonEdi)
    If haysel Then
        'Dibuja texto con selecci�n
        If yt >= sel1.yt And yt <= sel2.yt Then
            Call DibLinSel(y, yc, yt, linvis)
        Else    'L�nea sin selecci�n
            'Dibuja el texto sin selecci�n
            pic.ForeColor = mColTxtNor
            TextOut pic.hdc, 0, y, linvis, Len(linvis)
        End If
    Else
        'Dibuja el texto sin selecci�n
        pic.ForeColor = mColTxtNor
        TextOut pic.hdc, 0, y, linvis, Len(linvis)
    End If
End Sub

Private Sub DibujaLinActual()
'Dibuja la l�nea actual (curYt).
    DibujaLin curYt, True
End Sub

Private Sub DibujaLin(yt As Long, Optional BorraFondo As Boolean = True)
'Refresca una l�nea completa que est� en la posici�n indicada en coordenadas
'de texto (1..nLin). Por defecto borra el fondo antes de dibujar el texto.
'Dibuja la l�nea de texto a partir de su Vector de descripci�n, logrando
'texto multicolor.
Dim xc As Integer
Dim yc As Long, yp As Long
Dim i As Integer, j As Integer
Dim seg As String   'texto del segmento
Dim txtVis As String
Dim pos As Integer  'variable para buscar segmento
Dim tamaju As Integer   'tama�o ajustado del primer segmento
Dim txt As String
Dim lin() As TDesSeg
    'Verifica si escapa del texto
    If yt < 1 Or yt > nlin Then Exit Sub
    yc = yt - fil1 + 1   'Coord. de cursor
    If yc < 1 Or yc > maxLinVis Then Exit Sub   'fuera de pantalla
    
    'Verifica si hay selecci�n para dbujar en B/N
    If LineaEnSel(yt) Then
        'No nos complicamos
        Call DibujaLinBN(yt, BorraFondo)
        Exit Sub
    End If
    
    'analiza toda la l�nea porque los colores
    'pueden depender de elementos no visibles
    txt = linexp(yt)                'lee toda la l�nea
    If lincol(yt).tip = TLIN_DES Then
        'No hay descripci�n, hay que actualizar
        ActualDescColFil txt, lin()
        lincol(yt).tip = TLIN_MIX
        lincol(yt).seg = lin    'copia descripci�n de l�nea
    Else    'ya tiene descripci�n de segmento
        lin() = lincol(yt).seg()
    End If
    
    yp = (yt - fil1) * altcarP  'actualiza coordenada vertical en pixeles
    'Dibuja fondo de l�nea
    If BorraFondo Then Call DibBloFonC(yc, 1, maxColVis + 1, mColFonEdi)
    '-------Busca segmento de inicio "i"-------
    i = 1   'Se asume que empieza en el segmento 1
    pos = 1
    For i = 1 To UBound(lin)
        pos = pos + lin(i).tam
        If pos > col1 Then
            'Este es el segmento que contiene el punto inicial.
            'Calcula el tama�o ajustado del primer segmento a
            'dibujar que puede estar fragmentado.
            tamaju = pos - col1
            Exit For
        End If
    Next
    txtVis = Mid$(txt, col1, maxColVis)     'texto visible para graficar
    'Si no cae en ning�n segmento, i termina con Ubound(lin)+1
    '-------Imprime desde el segmento "i"------
    xc = 1  'caracter inicial
    For j = i To UBound(lin)
        pic.ForeColor = lin(j).col
        If j = i Then
            'S�lo para el primer segmento, el tama�o puede variar
            seg = Mid$(txtVis, xc, tamaju)       'texto del segmento
            TextOut pic.hdc, (xc - 1) * anccarP, yp, seg, Len(seg)
            xc = xc + tamaju
        Else
            seg = Mid$(txtVis, xc, lin(j).tam)   'texto del segmento
            TextOut pic.hdc, (xc - 1) * anccarP, yp, seg, Len(seg)
            xc = xc + lin(j).tam
        End If
        If xc > maxColVis Then
            Exit For 'ya no es visible
        End If
    Next
End Sub

Private Sub Dibujar(Optional RefresPIC As Boolean = True)
'Dibuja el texto completo que es visible en el control "pic". Dibuja en un solo color.
'Por defecto limpia el fondo a dibujar
Dim yp As Long
Dim i As Long
Dim textVis As String    'texto visible en la ventana
Dim numlin As String
Dim x1 As Long, x2 As Long
Dim rc As RECT
    'rc.Left = 0: rc.Top = 0    'ya est� inicializado
    If RefresPIC Then   'limpia ventana
'        pic.Refresh: Exit Sub   'El "Refresh", llamar� a "Paint" y a Dibujar()
        rc.Right = pic.ScaleWidth: rc.Bottom = pic.ScaleHeight
        hBrush = CreateSolidBrush(mColFonEdi)
        FillRect pic.hdc, rc, hBrush 'Es m�s r�pido que "Rectangle"
    End If
Call RecalculaMaxColVis
    If nlin = 0 Or fil1 = 0 Then Exit Sub
    If maxLinVis = 0 Or maxColVis = 0 Then Exit Sub
    yp = 0
    LeerXPosSel x1, x2
    FijaRelleno mColFonSel   'Relleno para la selecci�n
    'Dibuja por l�neas
    For i = fil1 To nfilFin
        If i = curYt Then
            DibujaLinActual
        Else
            DibujaLin i, False  'dibuja sin pintar el fondo
        End If
    Next
    If verNumLin Then   'Dibuja n�mero de l�nea
        'Borra columna
        rc.Right = ancNLinP: rc.Bottom = pic.ScaleHeight
        hBrush = CreateSolidBrush(mColFonNli)
        FillRect UserControl.hdc, rc, hBrush
        UserControl.ForeColor = vbBlack
        'Dibuja n�meros
        yp = 0
        For i = fil1 To nfilFin
            numlin = i
            TextOut UserControl.hdc, 0, yp + 2, numlin, Len(numlin)
            yp = yp + altcarP    'actualiza coordenada vertical
        Next
    End If
    'Actualiza barra de desplazamiento
    pintando = True     'activa bandera para evitar lanzar otra vez el evento "Paint"
    If CInt((fil1 - 1) * facdesV + 1) > VScroll1.Max Then
        'Esta situaci�n no deber�a producirse pero, parece que con muchas
        'lineas el redondeo puede ocasionar exceso
        MsgBox "Error de ajuste vertical: " & (fil1 - 1) * facdesV + 1 - VScroll1.Max
        VScroll1.Value = VScroll1.Max
    Else
        VScroll1.Value = (fil1 - 1) * facdesV + 1
    End If
    If col1 > HScroll1.Max Then
        MsgBox "Error de ajuste horizontal."
        HScroll1.Max = col1
        HScroll1.Value = col1
    Else
        HScroll1.Value = col1
    End If
    'MsgBox HScroll1.Max
    pintando = False
End Sub

Private Function CurMenorPos(pos As Tpostex) As Boolean
'Compara el cursor actual con una posici�n
Dim poscur As Tpostex
    poscur.xt = curXt
    poscur.yt = curYt
    CurMenorPos = MenorPos(poscur, pos)
End Function

Private Function CurMayorPos(pos As Tpostex) As Boolean
'Compara el cursor actual con una posici�n
Dim poscur As Tpostex
    poscur.xt = curXt
    poscur.yt = curYt
    CurMayorPos = MayorPos(poscur, pos)
End Function

Private Function PosSigPos(pos As Tpostex, n As Long) As Tpostex
'Devuelve la siguiente posici�n a partir de una posici�n base,
'proyectado "n" caracteres adelante. Trabaja en coordenadas de texto
'S�lo funciona en el modo de seleci�n normal.
Dim xt As Integer
Dim yt As Long
Dim lin1 As String  'primera l�nea
    PosSigPos = pos
    If n = 0 Then Exit Function
    lin1 = linrea(pos.yt)   'lee primera l�nea
    xt = PosXTreal(pos.xt, pos.yt)
    If xt + n <= Len(lin1) + 1 Then
        'Caso simple. No se escapa de la l�nea
        PosSigPos.yt = pos.yt
        PosSigPos.xt = PosXTexp(xt + n, pos.yt) 'posici�n expandida
    Else
        'Caso m�s complicado, porque pasa a otras l�neas
        n = n - (Len(lin1) + 1 - xt)    'quita tama�o del restante de l�nea 1
        yt = pos.yt
        While n > 0
            'Aqu� deben estar los dos caracteres CR y LF
            n = n - 2   'Los quitamos
            yt = yt + 1     'nos movemos a la siguiente l�nea
            If n < 0 Then
                'Rayos!, algo no anda bien
                MsgBox "Error de ajuste de salto de l�nea"
                Exit Function
            End If
            'Aqu� puede estar la siguiente l�nea
            If n = 0 Then
                'Ya no hay m�s l�neas
                PosSigPos.yt = yt   'en la siguiente
                PosSigPos.xt = 1    'al inicio
                Exit Function
            ElseIf n > 0 Then
                'A�n no se cubren todos los caracteres
                If n > Len(linrea(yt)) Then
                    'Toma siguiente l�nea completa
                    n = n - Len(linrea(yt))
                Else
                    'Es la �ltima l�nea
                    PosSigPos.yt = yt   'en la siguiente
                    PosSigPos.xt = PosXTexp(n + 1, yt)
                    Exit Function
                End If
            End If
        Wend
    End If
End Function

Public Sub SelecIdentificador(xt As Integer, yt As Long, largo As Long)
'Selecciona una cadena en el editor a partir de la posici�n indicada. Recibe coordenadas
'de texto. No redibuja.
Dim p As Tpostex
    p.xt = PosXTexp(xt, yt)     'Necesita la posici�n expandida
    p.yt = yt
    'Selecciona cadena
    posCursorA p
    Call FijarSel0      'Fija punto base
    posCursorA2 PosSigPos(p, largo)
    Call ExtenderSel 'Extiende selecci�n
End Sub

Private Sub DibTextPos(p1 As Tpostex, p2 As Tpostex)
'Dibuja las l�neas entre las posiciones p1 y p2.
'Si p1 es menor que p2, se corrige.
Dim f As Long
    If p1.yt <= p2.yt Then
        For f = p1.yt To p2.yt
            Call DibujaLin(f)
        Next
    Else
        For f = p2.yt To p1.yt
            Call DibujaLin(f)
        Next
    End If
End Sub

Private Sub ActLimitesBarDesp()
'Actualiza los l�mites de las barras de desplazamiento
Dim nLinVis As Integer
    'Calcula el n�mero de l�neas visibles en el editor
    nLinVis = nfilFin - fil1 + 1

    If nlin > 32700 Then
        'Verifica si se puede trabajar con desplazamientos simples
        'de la barra vertical
        facdesV = 1 / (Int(nlin / 32700) + 1)
    Else    'Si se puede
        facdesV = 1     'factor de desplazamiento vertical
    End If
    If nlin + 1 > maxLinVis Then
        VScroll1.Enabled = True
        VScroll1.Max = (nlin - nLinVis) * facdesV + 1 'Valor m�ximo
        If nLinVis > 0 Then VScroll1.LargeChange = nLinVis
    Else
        VScroll1.Enabled = False
    End If
    
    If maxTamLin + 1 > maxColVis Then
        HScroll1.Enabled = True
        HScroll1.Max = MaxCol1
        If maxColVis > 0 Then HScroll1.LargeChange = maxColVis
    Else    'deshabilita
        HScroll1.Enabled = False
    End If
End Sub

'**********************************************************************************
'******************************FUNCIONES DE NIVEL MAYOR****************************
'**********************************************************************************
Public Sub CargarArch(arch As String)
'M�todo inicial para cargar un archivo de texto en el editor
Dim nar As Integer
Dim linea As String
Dim a() As String
Dim i As Long
    If Dir(arch) = "" Then
        MsgBox "No se encuentra archivo: " & arch
        Exit Sub
    End If
    Call LimpiarLineas
    'abre archivo de datos
    archivo = arch
    nar = FreeFile
    Open archivo For Input As #nar
    'OJOOOO que si hay una l�nea en blanco al final, no se lee
    'porque "Line Input" lee incluyendo el salto de l�nea final si lo encuentra
    Do While Not EOF(nar)
        Line Input #nar, linea
        If InStr(linea, Chr(10)) <> 0 Then
            'Hay saltos de l�nea, debe ser un formato unix
            tipArch = 1
            a = Split(linea, Chr(10))
            For i = 0 To UBound(a)
                AgregaLinea a(i)    'Agregamos l�nea
            Next
        Else
            AgregaLinea linea   'Agrega la l�nea tal como se lee
        End If
        If nlin > MAX_LIN_EDI Then
            MsgBox "Demasiadas l�neas para leer en el editor"
            Exit Do
        End If
    Loop
    Close #nar
    tCursorA 1, 1
    Call ActualizaNLinFin   'actualiza las l�neas visible
'    Call UserControl_Resize
    Call Dibujar
    Call InicDeshacer       'Inicia deshacer
    Call FijarTextNoModif   'Fija punto de "No Modificado"
End Sub

Public Sub GuardarArch()
'M�todo inicial para guardar el archivo de texto del editor
    If archivo = "" Then
        MsgBox "No se ha especificado un nombre para el archivo", vbExclamation
        Exit Sub
    End If
    GuardarArchComo archivo
End Sub

Public Sub GuardarArchComo(nomb As String)
'M�todo inicial para guardar el archivo de texto del editor
Dim nar As Integer
Dim f As Long
    archivo = nomb  'actualiza nombre actual
    nar = FreeFile
    Open archivo For Output As #nar
    For f = 1 To nlin
        Print #nar, linrea(f)
    Next
    Close #nar
'    Call InicDeshacer       'Inicia deshacer
    Call FijarTextNoModif   'Fija punto de "No Modificado"
End Sub

Private Sub LimpSelec(Optional refres As Boolean = False)
'Quita el �rea seleccionada, del control. Por defecto no actualiza la pantalla,
'pero si "refres" es TRUE, se redibuja la pantalla si es necesario
    If haysel Then      'Hab�a una selecci�n
        haysel = False  'desactiva
        If refres Then  'Hay que refrescar
            If sel1.yt = sel2.yt Then   'S�lo basta con dibujar la l�nea
                Call DibujaLin(sel1.yt)
            Else    'Hay que dibujar varias l�neas
                Call Dibujar
            End If
        End If
        sel1 = sel0         'Inicia selecci�n nula
        sel2 = sel0         'Inicia selecci�n nula
    End If
End Sub

Public Sub SeleccionaTodo()
'Selecciona todo el texto contenido en el editor
    If nlin = 0 Then Exit Sub
    Redibujar = False
    'se mueve al inicio
    tCursorA 1, 1
    Call FijarSel0      'Fija punto base
    'nos movemos al final
    tCursorA2 maxTamLin + 1, nlin
    curXd = curXt      'actualiza posici�n deseada
    Call ExtenderSel
End Sub

Public Sub SelecLinea(yt As Long)
'Funci�n p�blica para seleccionar l�nea del texto
    Redibujar = True       'para no complicarnos, dibuja todo
    If haysel Then Call LimpSelec
    'Selecciona l�nea
    tCursorA 1, yt
    Call FijarSel0      'Fija punto base
    tCursorA2 maxTamLin + 1, yt
    Call ExtenderSel 'Extiende selecci�n
End Sub

Public Sub PegaSeleccion()
'Pega el texto seleccionado al control
'No hay problema en pegar selecciones grandes de texto
    On Error GoTo errPegSel
    CurInsertar Clipboard.GetText
    On Error GoTo 0
    Exit Sub
errPegSel:
    MsgBox "Error Leyendo el portapapeles.", vbExclamation
    On Error GoTo 0
End Sub

Public Sub CortaSeleccion()
'Elimina el texto seleccionado y copia la selecci�n al portatpapeles
    Call CopiaSeleccion
    If haysel Then Call CurEliminar
End Sub

Public Sub CopiaSeleccion()
'Copia el texto seleccionado al portapapeles
Dim hData As Long   'Manejador de memoria
Dim nbytes As Long
    If nlin = 0 Then Exit Sub   'por seguridad
    '---------Obtiene selecci�n-------------
    'Copia selecci�n a memoria
    hData = BloAMem(nbytes, sel1, sel2)
    If hData = 0 Then
        MsgBox "No se puede copiar texto. Error asignando memoria", vbCritical
        Exit Sub
    End If
    '---------Copia al portapapeles-------------
    If OpenClipboard(0) Then
        Call EmptyClipboard
        'SetClipboardData CF_METAFILEPICT, hGlobal
        Call SetClipboardData(CF_TEXT, hData)
        'No es necesario ya liberar "hData", porque el portapapapeles lo har�
        'cuando ya no lo necesite
        Call CloseClipboard
    Else    'Fallo abrir el Portapapeles
        'Liberamos la memoria porque no la vamos a usar
        GlobalFree hData
    End If
End Sub

Private Function ElimBloq(s1 As Tpostex, s2 As Tpostex) As Long
'Elimina el bloque de texto definido por s1 y s2. Actualiza s1 y s2
'No realiza refresco de pantalla. Devuelve las filas eliminadas.
Dim f1 As Long, f2 As Long
Dim f As Long
Dim xt1 As Integer, xt2 As Integer
Dim xtmp As Integer
Dim tmp As String
    f1 = s1.yt    'posici�n vertical
    f2 = s2.yt    'posici�n vertical
    If tipSelec = 1 Then    '---------Selecci�n por columnas----------
        'calcula posiciones horizontales en el texto
        xt1 = s1.xt: xt2 = s2.xt
        If xt1 > xt2 Then   'Verifica si hay que invertir
            xtmp = xt1: xt1 = xt2: xt2 = xtmp
        End If
        'Quita selecci�n de las l�neas afectadas
        For f = f1 To f2
            'Para no complicarnos con las tabulaciones, expandimos toda la l�nea
            'antes de eliminar. Lo optimo ser�a analizar que tabulaciones son
            'afectadas y expandirlas s�lo a ellas.
            linrea(f) = LineaFin(linrea(f))
            EliminarCad linrea(f), xt1, xt2 - xt1
        Next
        ElimBloq = f2 - f1 + 1 'n�mero de filas eliminadas
    Else              '---------------Selecci�n normal----------------
        'calcula posiciones horizontales reales
        'se asume que siempre s1 est� antes que s2
        xt1 = PosXTreal(s1.xt, s1.yt)
        xt2 = PosXTreal(s2.xt, s2.yt)
        'Elimina de acuerdo a la posici�n
        If f1 = f2 Then     'Est�n en la misma fila
            EliminarCad linrea(f1), xt1, xt2 - xt1
            ElimBloq = 1   'z�lo se elimina de una fila
        ElseIf f1 < f2 Then
            'Procesa fila contiene inicio de selecci�n
            EliminarCad linrea(f1), xt1
            'Procesa fila contiene fin de selecci�n
            EliminarCad linrea(f2), 1, xt2 - 1
            'Elimina las filas intermedias
            If linrea(f2) = "" Then
                '-----Se eliminan la fila final completa
                EliminarLineas f1 + 1, f2 - f1
            Else
                '-----Se eliminan filas a medias. Hay que juntar
                'rescata lo que va a quedar de la fila final
                tmp = linrea(f2)
                'elimina hasta la fila final
                EliminarLineas f1 + 1, f2 - f1
                'agrega lo que rescat�
                linrea(f1) = linrea(f1) & tmp
            End If
            ElimBloq = f2 - f1 + 1 'n�mero de filas eliminadas
        End If
    End If
    'Actualiza nuevas posiciones de selecci�n
    s2 = s1
    'Actualiza por si han desaparecido l�neas de la pantalla
    Call ActualizaNLinFin
End Function

Private Function ElimSelecDib(Optional refres As Boolean = True) As Long
'Elimina la zona seleccionada. Actualiza las variables sel1 y sel2
'Refresca la pantalla por defecto. Devuelve las filas eliminadas.
'Se asume que la selecci�n debe contener al cursor actual.
Dim f As Long
Dim yt2 As Long
Dim nfilsel As Long
    If bloqText Then Exit Function   'Hay protecci�n
    yt2 = sel2.yt   'Guarda posici�n final antes de eliminar
                    'bloque, por si se necesita
    nfilsel = ElimBloq(sel1, sel2)
    If nfilsel = 1 Then    's�lo modific� una l�nea
        lincol(curYt).tip = TLIN_DES    'Fuerza a actualizar colores
        Redibujar = False   'prepara bandera
        'ubica de nuevo el cursor para validar posici�n
        posCursorA2 sel1    'Aqu� se puede actualizar "Redibujar"
    Else    'Se han modificado varias l�neas
        'Actualiza estado de sintaxis
        If tipSelec = 1 Then    'Varias filas alteradas
            For f = sel1.yt To yt2
                lincol(f).tip = TLIN_DES     'Actualizar en la 1ra l�nea
            Next
        Else
            lincol(sel1.yt).tip = TLIN_DES    'Actualizar en la 1ra l�nea
        End If
        'ubica cursor
        posCursorA2 sel1
        Redibujar = True    'Fuerza a redibujar
    End If
    haysel = False  'antes de dibujar, para refrescar correctamente
    If refres Then  'Verifica si se debe refrescar
        If Redibujar Then
            'Ha habido movimiento de pantalla o se han eliminado varias l�neas
            Call Dibujar
'            Call ActualizaNLinFin    'Para dibujar correctamente
            Call ActLimitesBarDesp 'actualiza l�mites de Scroll Bar's
        Else    'S�lo es necesario refrescar la l�nea afectada
            Call DibujaLin(curYt)
        End If
        Call EncenCursor    'el cursor estaba desactivado
    End If
    Call FijarSel0      'Fija punto base de selecci�n
    ElimSelecDib = nfilsel  'Devuelve filas eliminadas
End Function

Public Sub CurInsertar(cad As String)
'Inserta una cadena en la posici�n actual del cursor
'Guarda informaci�n para deshacer
Dim xt As Integer, yt As Long
Dim xtr As Integer
Dim tmp As String
Dim f As Long
Dim lcad() As String
Dim ncad As Long
Dim tam As Integer  'Tama�o de cadena
Dim pcur As Tpostex 'Guarda posici�n de cursor
Dim pmax As Tpostex 'Guarda posici�n de cursor
Dim nadi As Long    'L�neas adicionales
Dim s1 As Tpostex, s2 As Tpostex    'para selecci�n
'Dim yt2 As Long     'yt2 para el modo multil�nea
Dim nfilsel As Long
    If bloqText Then Exit Sub   'Hay protecci�n
    
'    If cad = "" Then Exit Sub
    If nlin = 0 Then    'caso especial. No hay nada
        'Es el primer caracter que se crea
        AgregaLinea ""
        maxTamLin = 1
        FijaCursor 1, 1
        curXd = 1     'Inicia posici�n X deseada de cursor
        Call FijarSel0  'inicia par�metros de selecci�n
    End If
    'Verifica si hay texto seleccionado
    If haysel Then
        'Se debe primero eliminar el texto selecionado.
        GuarAcc TU_ELI, sel1, TextSel()  'para deshacer
        s1 = sel1: s2 = sel2    'Guardar por si acaso
        nfilsel = ElimSelecDib(False) 'Elimina sin refrescar
        'Verifica si hay Inserci�n en modo multil�nea
        If tipSelec = 1 And nfilsel > 1 And InStr(cad, vbCrLf) = 0 Then
            'Crea r�pidamente una cadena de varias l�neas
            ReDim lcad(1 To nfilsel)
            For f = 1 To nfilsel: lcad(f) = cad: Next
            tmp = Join(lcad, vbCrLf)
            'Inserta en la posici�n actual, se hace recursivamente para
            'evitar lidiar con el "deshacer" y los detalles del refresco.
            CurInsertar tmp     'Llamada recursiva
            'Restaura la selecci�n para poder seguir escribiendo
            s1.xt = s1.xt + Len(cad)    'corrige desplazamiento
            's2.xt = s2.xt + Len(cad)    'corrige desplazamiento
            s2.xt = s1.xt   'debe haber siempre cero columnas
            sel1 = s1: sel2 = s2
            haysel = True
            Call Refrescar
            Exit Sub        'No hay m�s que hacer
        End If
    End If
    'Calcula posici�n horizontal real en la cadena considerando
    'tabulaciones. Se hace despu�s de eliminar una posible selecci�n
    'para tener la nueva posici�n
    'Toma posiciones en el texto
    xt = curXt
    yt = curYt
    If xt < 1 Or yt < 1 Then Exit Sub
    xtr = PosXTreal(xt, yt)
    'Inserta cadena en el texto
    If InStr(cad, vbCrLf) = 0 Then
        If Len(linrea(yt)) + Len(cad) > MAX_ANC_LIN Then   'Protecci�n
            MsgBox "ERROR: L�nea muy larga"
            Exit Sub
        End If
        GuarAcc TU_INS, LeePosCur, cad   'Guarda acci�n para deshacer
        '------- Insertar Cadena de una sola l�nea -----------
        InsertarCad linrea(yt), xtr, cad
        lincol(yt).tip = TLIN_DES   'Fuerza a actualizar colores
        linact = linexp(yt)    'actualiza l�nea actual porque se ha cambiado
                               'Se debe hacer antes de llamar a DesplazaCursor()
        'Actualiza tama�o de l�nea m�s larga
        'Se deba hacer antes de DesplazaCursor() para tener actualizada
        'la barra de desplazamiento antes de dibujar
        If Len(linact) > maxTamLin Then
            maxTamLin = Len(linact)
            Call ActLimitesBarDesp  'actualiza barra
        End If
        If Redibujar Then   'Verifica si es necesario dibujar todo
            Call Dibujar
        Else
            Call DibujaLinActual        'Refresca la l�nea actual
        End If
        DesplazaCursor DIR_DER, Len(cad)    'Mueve cursor
    Else
        '------ Insertar cadena de varias l�neas ---------
        If tipSelec = 1 Then '---------------Modo por columnas---------------
            pcur = LeePosCur    'Guarda posici�n actual de cursor
            pmax = MaxPos       'Guarda posici�n del final
            lcad = Split(cad, vbCrLf)  'separa en l�neas
            ncad = UBound(lcad) '�ltimo �ndice
            'Agrega fila por fila
            nadi = 0 'inicia contador
            For f = 0 To ncad
                If yt + f > nlin Then   'No hay l�nea. hay que agregarla
                    Call AgregaLinea(Space(xt - 1)) 'se le da el tama�o necesario
                    nadi = nadi + 1
                Else    'Ya hay l�nea.
                    'No nos complicamos y expandemos las tabulaciones
                    'Aqu� podemos tener problemas con deshacer
                    linrea(yt + f) = linexp(yt + f)
                    tam = Len(linrea(yt + f))   'guarda tama�o
                    If tam < xt - 1 Then
                        'Cadena muy peque�a, completar con espacios
                        linrea(yt + f) = linrea(yt + f) & Space(xt - tam - 1)
                    End If
                End If
                InsertarCad linrea(yt + f), xt, lcad(f)
                lincol(yt + f).tip = TLIN_DES 'Fuerza a actualizar colores
            Next
            If nadi > 0 Then    '�Hubo l�neas agregadas?
                'Guarda la acci�n de deshacer de golpe
                For f = 1 To nadi
                    'Puede ser lento para miles de l�neas
                    tmp = tmp & vbCrLf & Space(xt - 1)
                Next
                GuarAcc TU_INSn, pmax, tmp  'Insertar normal
            End If
            GuarAcc TU_INS, pcur, cad    'Guarda acci�n principal para deshacer
            'mueve cursor al final de la cadena pegada
            tCursorA2 xt + Len(lcad(0)), curYt + ncad
            curXd = curXt      'actualiza posici�n deseada
            Call ActualizaNLinFin   'Para dibujar correctamente
            Call ActLimitesBarDesp  'actualiza l�mites de Scroll Bar's
            Call FijarSel0      'Fija punto base, como lo har�a "DesplazaCursor()"
            'Ha cambiado bastante, mejor actualizamos todo
            Call Dibujar
            Call EncenCursor    'Enciende para que sea visible en la nueva posici�n
        Else                 '---------------Modo normal---------------------
            GuarAcc TU_INS, LeePosCur, cad   'Guarda acci�n para deshacer
            lcad = Split(cad, vbCrLf)  'separa en l�neas
            ncad = UBound(lcad)     '�ltimo �ndice
            tmp = linrea(yt)        'lee l�nea afectada
            'Inserta las l�neas necesarias en la posici�n del cursor
            InsertarLineas yt, ncad
            'corta l�nea y agrega l�nea inicial del portapapeles
            linrea(yt) = Mid$(tmp, 1, xtr - 1) & lcad(0)
            lincol(yt).tip = TLIN_DES 'Fuerza a actualizar colores
            'actualiza l�neas internmedias
            For f = 1 To ncad - 1
                linrea(yt + f) = lcad(f)
                lincol(yt + f).tip = TLIN_DES 'Para forzar a analizar colores
            Next
            'actualiza l�nea final
            linrea(yt + ncad) = lcad(ncad) & Mid$(tmp, xtr)
            lincol(yt + ncad).tip = TLIN_DES 'Fuerza a actualizar colores
            'mueve cursor al final de la cadena pegada
            tCursorA Len(lcad(ncad)) + 1, curYt + ncad
            curXd = curXt      'actualiza posici�n deseada
            Call ActualizaNLinFin   'Para dibujar correctamente
            Call ActLimitesBarDesp  'actualiza l�mites de Scroll Bar's
            Call FijarSel0      'Fija punto base, como lo har�a "DesplazaCursor()"
            'Ha cambiado bastante, mejor actualizamos todo
            Call Dibujar
            Call EncenCursor    'Enciende para que sea visible en la nueva posici�n
        End If
    End If
End Sub

Public Sub CurEliminar(Optional forzardib As Boolean = False)
'Elimina un caracter en la posici�n actual del cursor.
'"forzardib" indica que se fuerza a redibujar toda la pantalla
'Guarda informaci�n para deshacer
Dim xt As Integer
Dim yt As Long
Dim xtr As Integer
Dim tmp As String
    If bloqText Then Exit Sub   'Hay protecci�n
    '---------Si hay selecci�n, s�lo elimina y sale-------------
    If haysel Then
        GuarAcc TU_ELI, sel1, TextSel() 'para deshacer
        Call ElimSelecDib
        Exit Sub
    End If
    '-------No hay selecci�n, se debe eliminar lo solicitado------
    If nlin = 0 Then Exit Sub   'no hay nada que eliminar
    'Toma posiciones en el texto
    xt = curXt
    yt = curYt
    If xt < 1 Or yt < 1 Then Exit Sub
    'Calcula posici�n horizontal real en la cadena considerando tabulaciones
    xtr = PosXTreal(xt, yt)
    If xtr = Len(linrea(yt)) + 1 And yt < nlin Then
        GuarAcc TU_ELI, LeePosCur(), vbCrLf    'para deshacer
        'Esta al final de la l�nea y hay m�s l�neas.
        'copia contenido de l�nea siguiente
        tmp = linrea(yt + 1)
        'agrega a l�nea actual
        linrea(yt) = linrea(yt) & tmp
        lincol(yt).tip = TLIN_DES  'Fuerza a actualizar colores
        'reposiciona cursor para validar y actualizar "linact"
        tCursorA xt, yt
        curXd = curXt      'actualiza posici�n deseada
        'Eliminamos la siguiente l�nea
        EliminarLineas yt + 1, 1
        Call ActualizaNLinFin
        Call ActLimitesBarDesp  'Actualiza l�mites de Scroll Bar's
        Call FijarSel0      'Fija punto base, como lo har�a "DesplazaCursor()"
        Call Dibujar    'Refresca. En realidad s�lo podr�a ser necesario dibujar
                        's�lo las l�neas de abajo.
    Else    'Caso de eliminaci�n normal
        tmp = EliminarCad(linrea(yt), xtr, 1)
        lincol(yt).tip = TLIN_DES  'Fuerza a actualizar colores
        GuarAcc TU_ELI, LeePosCur(), tmp   'para deshacer
        linact = linexp(yt)    'actualiza l�nea actual porque se ha cambiado
        'Se deber�a actualizar "maxTamLin", si es que disminuye
        'pero es un proceso muy pesado para hacerse aqu�
        If forzardib Then   '�Dibujar todo?
            Call Dibujar    'Dibuja todo
        Else    'S�lo dibuja la l�nea afectada
            Call DibujaLinActual    'Refresca l�nea
        End If
        'El cursor se queda en su lugar
    End If
    Call EncenCursor    'Lo hace visible para visualizar mejor
End Sub

Public Sub CurEliminarCad(cad As String)
'Elimina "n" caracteres desde la posici�n actual del cursor en el control .
'El valor "n" se determina por el tama�o de "cad" y por el tipo de selecci�n
'No se deber�a usar para editar el texto del editor, sino s�lo para
'las opciones de "deshacer"
Dim p1 As Tpostex, p2 As Tpostex
Dim n As Long
Dim a() As String
Dim f As Long
Dim yt2 As Long
    If bloqText Then Exit Sub       'Hay protecci�n
    If Len(cad) = 0 Then Exit Sub   'Verificaci�n
    'Define el bloque a eliminar
    p1 = LeePosCur                  'Toma inicio de bloque
    If tipSelec = 1 Then '---------------Modo por columnas---------------
       a = Split(cad, vbCrLf)       'separa cadena
       p2.yt = p1.yt + UBound(a)    'calcula l�mite
       p2.xt = p1.xt + Len(a(0))    'calcula l�mite
       
    Else                 '---------------Modo normal---------------
        n = Len(cad)
        p2 = PosSigPos(p1, n)   'calcula l�mite de bloque
    End If
    yt2 = p2.yt     'Guarda fila final
    '-----------------Actualiza Pantalla--------------------
    If ElimBloq(p1, p2) = 1 Then    's�lo modific� una l�nea
        lincol(p1.yt).tip = TLIN_DES  'Para actualizar colores
        Redibujar = False   'prepara bandera
        'ubica de nuevo el cursor para validar posici�n
        posCursorA2 p1
        If Redibujar Then
            'Ha habido movimiento de pantalla
            Call Dibujar
        Else    'S�lo es necesario refrescar la l�nea afectada
            Call DibujaLin(curYt)
        End If
    Else    'Se han modificado varias l�neas
        lincol(p1.yt).tip = TLIN_DES  'Para actualizar colores
        If tipSelec = 1 Then
            'Eliminaci�n en varias l�neas, marca las siguientes
            For f = p1.yt + 1 To yt2
                lincol(f).tip = TLIN_DES
            Next
        End If
        'ubica cursor
        posCursorA2 sel1
        Call Dibujar           'Refresca todo
        Call ActualizaNLinFin  'Para dibujar correctamente
        Call ActLimitesBarDesp 'actualiza l�mites de Scroll Bar's
    End If
    Call FijarSel0      'Fija punto base de selecci�n
    Call EncenCursor    'el cursor estaba desactivado
End Sub

Public Sub CurEliminarB()
'Elimina un caracter en la posici�n actual del cursor, hacia atr�s
Dim alinicio As Boolean
    If bloqText Then Exit Sub   'Hay protecci�n
    '---------Si hay selecci�n, s�lo elimina y sale-------------
    If haysel Then ElimSelecDib: Exit Sub
    '-------No hay selecci�n, se debe eliminar lo solicitado------
    If nlin = 0 Then Exit Sub   'no hay nada que eliminar
    'Retrocede el cursor
    Redibujar = False   'inicia bandera
    If curXt = 1 Then   'Est� al inicio de l�nea
        If curYt > 1 Then       'hay l�nea anterior
            tCursorA2 Len(linexp(curYt - 1)) + 1, curYt - 1
            curXd = curXt      'actualiza posici�n deseada
        Else
            alinicio = True     'est� al inicio
        End If
    Else
        tCursorA2 curXt - 1, curYt
        curXd = curXt      'actualiza posici�n deseada
    End If
    Call FijarSel0      'Fija punto base, como lo har�a "DesplazaCursor()"
    'Elimina en la nueva posici�n. Indicando si es necesario redibujar
    If Not alinicio Then    'Verifica si se puede
        Call CurEliminar(Redibujar)    'Elimina en la nueva posici�n
    End If
End Sub

'*************************************************************************************
'************************* FUNCIONES PARA OPCIONES DE B�SQUEDA ***********************
'*************************************************************************************

Private Function BuscarCadPos(bus As String, p1 As Tpostex, p2 As Tpostex, _
                    Optional ignCaja As Boolean = True) As Tpostex
'Busca una cadena de texto cargado en el editor, en el bloque definido
'por pos1 y pos2, a partir de la posici�n pos1 hacia adelante.
'Devuelve la posici�n donde empieza la cadena encontrada. Si no encuentra,
'devuelve (0,0)
Dim cad As String
Dim pos As Integer
Dim f As Long
Dim cmp As VbCompareMethod
    If MenorPos(p2, p1) Then Exit Function
    If ignCaja Then
        cmp = vbTextCompare
    Else
        cmp = vbBinaryCompare
    End If
    If p1.yt = p2.yt Then    'Texto de una sola l�nea-------
        cad = TextPosLin(p1, p2)
        pos = InStr(1, cad, bus, cmp) 'busca
        If pos <> 0 Then
            BuscarCadPos.xt = p1.xt + PosXTexp(pos, p1.yt)
            BuscarCadPos.yt = p1.yt
            Exit Function
        End If
    Else                     'Hay varias l�neas---------------
        'busca en l�nea inicial
        cad = TextPosIni(p1)
        pos = InStr(1, cad, bus, cmp)   'busca
        If pos <> 0 Then
            BuscarCadPos.xt = p1.xt + PosXTexp(pos, p1.yt) - 1
            BuscarCadPos.yt = p1.yt
            Exit Function
        End If
        'busca en l�neas intermedias
        For f = p1.yt + 1 To p2.yt - 1
            cad = linrea(f)
            pos = InStr(1, cad, bus, cmp) 'busca
            If pos <> 0 Then
                BuscarCadPos.xt = PosXTexp(pos, f)
                BuscarCadPos.yt = f
                Exit Function
            End If
        Next
        'busca en l�nea final
        cad = TextPosFin(p2)
        pos = InStr(1, cad, bus, cmp) 'busca
        If pos <> 0 Then
            BuscarCadPos.xt = PosXTexp(pos, p2.yt)
            BuscarCadPos.yt = p2.yt
            Exit Function
        End If
    End If
End Function

Public Sub InicBuscar(bus As String, _
                      Optional ambito As Integer = AMB_TODO, _
                      Optional ignCaja As Boolean = True, _
                      Optional palComp As Boolean = False)
'Inicia una b�squeda definiendo sus par�metros.
'La cadena "bus" debe ser de una sola l�nea.
    If ambito = AMB_TODO Then
        'Se buscar� en todo el texto
        PosBus1 = MinPos
        PosBus2 = MaxPos
    ElseIf ambito = AMB_SELE Then
        'Se buscar� en la selecci�n
        PosBus1 = sel1
        PosBus2 = sel2
    End If
    PosEnc = PosBus1    'Fija posici�n inicial para buscar
    CadBus = bus        'Guarda cadena de b�squeda
    CajBus = ignCaja    'Guarda par�metro de caja
    PalCBus = palComp
End Sub

Public Function BuscarSig() As String
'Realiza una b�squeda iniciada con "InicBuscar"
'La b�squeda se hace a partir de la posici�n donde se dej� en la �ltima b�squeda.
'Devuelve la cadena de b�squeda.
Dim p As Tpostex
Dim p2 As Tpostex
    PosEnc = LeePosCur()    'Busca desde el cursor
    'Protecciones
    If PosNulo(PosEnc) Then Exit Function
    If PosNulo(PosBus2) Then Exit Function
    If MayorPos(PosBus2, MaxPos) Then PosBus2 = MaxPos
    If MayorPos(PosEnc, PosBus2) Then Exit Function
    'b�squeda
    If PalCBus Then 'Debe ser palabra completa
        p = BuscarCadPos(CadBus, PosEnc, PosBus2, CajBus)
        Do While p.xt <> 0
            p2 = PosSigPos(p, Len(CadBus))
            If EsPalabraCompleta(p, p2) Then Exit Do
            PosEnc = p2
            p = BuscarCadPos(CadBus, PosEnc, PosBus2, CajBus)
        Loop
    Else    'B�squeda normal
        p = BuscarCadPos(CadBus, PosEnc, PosBus2, CajBus)
        If p.xt <> 0 Then p2 = PosSigPos(p, Len(CadBus))
    End If
    'verifica si encontr�
    If p.xt <> 0 Then
        Redibujar = True       'para no complicarnos, dibuja todo
        If haysel Then Call LimpSelec
        'Selecciona cadena
        posCursorA p
        Call FijarSel0      'Fija punto base
        posCursorA2 p2
        Call ExtenderSel 'Extiende selecci�n
        BuscarSig = CadBus  'devuelve cadena
    Else
        BuscarSig = CadBus  'devuelve cadena
        MsgBox "No se encuentra el texto: '" & CadBus & "'", vbExclamation
    End If
End Function

Private Function EsPalabraCompleta(p1 As Tpostex, p2 As Tpostex) As Boolean
'Indica si la palabra en la posici�n [p,p+lar] es una palabra completa, es decir,
'que no est� en medio de un identificador
Dim Cant As String
Dim Csig As String
    If p1.xt = 0 Then Exit Function
    Cant = UCase(CarPosAnt(p1)) 'caracter anterior
    Csig = UCase(CarPos(p2))    'caracter siguiente
    If Not (Cant Like CAR_IDEN_VALM) And Not (Csig Like CAR_IDEN_VALM) Then
        EsPalabraCompleta = True
    End If
End Function

'*************************************************************************************
'************************* FUNCIONES PARA EL MANEJO DE DESHACER **********************
'*************************************************************************************
Private Sub elimUndos(n As Integer)
'Elimina "n" acciones al inicio de la matriz Undos().
'La eliminaci�n se hace siempre desde la acci�n 1, al inicio de la matriz.
Dim i As Integer
    If n > nUndo Then n = nUndo 'protecci�n
    If n <= 0 Then Exit Sub     'por protecci�n y evitar p�rdida de tiempo cuando n=0
    'Desplaza elementos
    For i = 1 To nUndo - n
        Undos(i) = Undos(i + n)
    Next
    'Elimina elementos finales
    nUndo = nUndo - n
    ReDim Preserve Undos(nUndo)
    'Mantiene la distancia con nTxtModif
    'obsrevar que nTxtModif, puede ser negativo, lo que significa que
    'ya no se puede recuperar el estado de "texto no modificado" porque
    'ya no se tienen la cantidad de acciones disponibles que se necesitan
    'para llegar a este estado.
    nTxtModif = nTxtModif - n
End Sub

Private Sub InicDeshacer()
'Inicia la herramienta DEHACER. Debe llamarse al inicio del editor
'y cuando ya no se pueden (o deben) recuperar los cambios anteriores
    elimUndos nUndo     'Elimina todas las acciones que puedan existir
    Deshaciendo = False
End Sub

Private Sub FijarTextNoModif()
'Fija el punto en que el el texto no est� modificado. Es decir
'el texto que no requiere grabaci�n.
'Deber�a llamarse en el momento de abrir un archivo o grabarse.
    nTxtModif = nUndo   'Apunta al �ndice nUndo actual.
End Sub

Public Function TextModificado() As Boolean
'Indica si el texto ha sufrido modificaci�n
    If nUndo = nTxtModif Then
        TextModificado = False   'El texto est� como al inicio
    Else
        TextModificado = True    'Se ha modificado el texto
    End If
End Function

Private Sub GuarAcc(acc As Integer, pos As Tpostex, cad As String)
'Guarda una acci�n de modificaci�n del texto para poder deshacerla luego
'Se debe llamar cada vez que se realiza un cambio en el texto
    If Deshaciendo Then Exit Sub    'No guarda acciones de tipo deshacer
    If TamMemDeshacer > TAM_MAX_UNDO Then
        InicDeshacer    'Protecci�n a grabar muchas acciones
    End If
    If nUndo > NAC_MAX_UNDO Then
        'Se alcanz� el tama�o m�ximo de acciones a deshacer
        elimUndos 1     'elimina la m�s antigua
    End If
    nUndo = nUndo + 1   'incrementa contador de acciones
    ReDim Preserve Undos(nUndo) 'agrega elemento
    Undos(nUndo).acc = acc
    Undos(nUndo).pos = pos
    Undos(nUndo).cad = cad  'Copia cadena de la acci�n.
End Sub

Private Sub EjecAcc(acc As Integer, pos As Tpostex, cad As String)
'Ejecuta una acci�n de modificaci�n del texto de tipo Tundo
Dim tipsel As Integer     'Modo de Selecci�n
    Deshaciendo = True  'Para evitar guardar las acciones del "deshacer"
    Select Case acc
    Case TU_INS     'Inserta texto
        Redibujar = False
        posCursorA2 pos 'ubica cursor
        CurInsertar cad 'Inserta la cadena indicada
    Case TU_INSn    'Inserta texto en modo normal
        tipsel = tipSelec      'Guarda tipo de selecci�n
        tipSelec = 0
        Redibujar = False
        posCursorA2 pos 'ubica cursor
        CurInsertar cad 'Inserta la cadena indicada
        tipSelec = tipsel   'Restaura tipo de selecci�n
    Case TU_ELI     'Elimina texto
        Redibujar = False
        posCursorA2 pos 'ubica cursor
        CurEliminarCad cad   'Elimina la cadena indicada
    Case TU_ELIn    'Elimina en modo normal
        tipsel = tipSelec      'Guarda tipo de selecci�n
        tipSelec = 0
        Redibujar = False
        posCursorA2 pos 'ubica cursor
        CurEliminarCad cad   'Elimina la cadena indicada
        tipSelec = tipsel   'Restaura tipo de selecci�n
    Case TU_SNOR    'Pasa a modo normal
        tipSelec = 0
    Case TU_SCOL    'Pasa a modo por columnas
        tipSelec = 1
    End Select
    Deshaciendo = False
End Sub

Private Sub EjecutarAcc(acc As Tundo)
'Ejecuta una acci�n de tipo Tundo
    EjecAcc acc.acc, acc.pos, acc.cad
End Sub

Private Sub DeshacerAcc(acc As Tundo)
'Deshace una acci�n de tipo Tundo
    EjecAcc -acc.acc, acc.pos, acc.cad
End Sub

Public Sub Deshacer()
'Deshace una acci�n previamente realizada
    If nUndo > 0 Then
        DeshacerAcc Undos(nUndo)
        nUndo = nUndo - 1   'decrementa
        ReDim Preserve Undos(nUndo)  'elimina siguiente acci�n
    End If
End Sub

Private Function TamMemDeshacer() As Long
'Devuelve la cantidad de caracteres (no de bytes) usados en la
'grabaci�n de las acciones de "deshacer".
Dim tmp As Long
Dim i As Integer
    For i = 1 To nUndo
        tmp = tmp + Len(Undos(i).cad)
    Next
    TamMemDeshacer = tmp
End Function

'*************************************************************************************
'***************************** C�DIGO DE RESPUESTA A EVENTOS *************************
'*************************************************************************************
Private Sub pic_OLEDragDrop(Data As DataObject, Effect As Long, Button As Integer, Shift As Integer, x As Single, y As Single)
'Se ha soltado un archivo
Dim arc As String
    If Data.GetFormat(vbCFFiles) Then
        'Hay nombre de archivos
        arc = Data.Files(1)     'Devuelve el primer archivo
        'Dispara evento
        RaiseEvent ArchivoSoltado(arc)
    End If
End Sub

Private Sub pic_MouseDown(Button As Integer, Shift As Integer, x As Single, y As Single)
'Se ha hecho click en el control
Dim xt As Integer
Dim yt As Long
'    If x < ancNLinP Then
'        'MsgBox "En columna de l�neas"
'        Exit Sub
'    End If
    
    'Movemos el cursor en la posici�n indicada
    xt = Round(x / anccarP) + col1
    yt = Int(y / altcarP) + fil1
    Redibujar = False
    tCursorA2 xt, yt
    curXd = curXt      'actualiza posici�n deseada
    If Button = 1 Then
        '---------bot�n izquierdo----------
        If Shift = 1 Then   'Con shift encendido
            Call ExtenderSel
        Else
            Call LimpSelec(True)        'Limpia selecci�n
            'Marca la posici�n del cursor antes de una selecci�n
            Call FijarSel0
            If Redibujar Then Call Refrescar
            Call EncenCursor    'Enciende para que sea visible en la nueva posici�n
        End If
        'Inicia bandera para arrastre
        pulsadoI = True
        xt0 = xt: yt0 = yt  'Inicia coordenadas para movimiento
    Else
        '---------bot�n derecho----------
    End If
    ultBotPul = Button  'Actualiza �ltimo bot�n pulsado
    'Verifica desactivaci�n de Ayuda Contextual
    If HayAyudC Then
        If curYt <> ytIniIden Then  'Se ha movido la l�nea
            FinAyudContextual   'Termina la ayuda contextual
        End If
    End If
    
End Sub

Private Sub pic_MouseMove(Button As Integer, Shift As Integer, x As Single, y As Single)
Dim xt As Integer
Dim yt As Long
'    If X  < ancNLinP Then
'        Exit Sub
'    End If
    If pulsadoI Then
        'Para indicar arrastre
'        UserControl.MousePointer = vbNoDrop
        '-----Contin�a selecci�n----
        'Movemos el cursor en la posici�n indicada
        xt = Int(x / anccarP) + col1
        yt = Int(y / altcarP) + fil1
        If xt0 = xt And yt0 = yt Then Exit Sub
        Redibujar = False
        tCursorA2 xt, yt      'Para realizar desplazamiento
        Call ExtenderSel
    End If
    xt0 = xt: yt0 = yt
'    RaiseEvent MouseMove(Button, Shift, x, y)
End Sub

Private Sub pic_MouseUp(Button As Integer, Shift As Integer, x As Single, y As Single)
    If Button = 1 Then
        pulsadoI = False
'        UserControl.MousePointer = vbDefault    'Termina arrastre
    ElseIf Button = 2 Then
        'Activa men� contextual si es que hay
        If Not (menuContext Is Nothing) Then
            PopupMenu menuContext
        End If
    End If
End Sub

Private Sub pic_DblClick()
    If ultBotPul = 1 Then
        '------Doble click izquierdo ---------
        Redibujar = False
        tCursorA2 curIniPal2(), curYt
        Call FijarSel0
        tCursorA2 curFinPal(), curYt
        Call ApagCursor 'Para que no interfiera
        Call ExtenderSel
    End If
End Sub

Private Sub UserControl_Initialize()
Dim tm As TEXTMETRIC
    'Oculta lista contextual
    lstCont.Visible = False
    
    
    pic.ScaleMode = vbPixels
    UserControl.ScaleMode = vbPixels
    facdesV = 1
    Call LimpiarLineas
    
    verDesHor = False
    
    FijaFil1 1      'fil1= 1
    FijaCol1 1      'col1= 1
    nEspTab = 6     '6 espacios para tabulaci�n
    
    'Inicia colores del editor
    mColFonEdi = vbWhite  'vbblack     'fondo de editor
    mColTxtNor = vbBlack  'vbWhite     'texto normal
    mColFonSel = RGB(130, 130, 255)
    mColTxtSel = vbWhite
    mColFonNli = RGB(200, 200, 200)
    mColTxtCom = RGB(128, 128, 128)
    mColTxtCad = RGB(90, 90, 255)
    mColPalRes = RGB(0, 190, 0)     'verde oscuro
    mColPalRes2 = vbRed     'verde oscuro
    mColTxtFun = RGB(0, 190, 0)     'verde oscuro
    
    pic.BackColor = mColFonEdi
    
    'Define el tipo de texto
    
    
    
    Call FijaTexto(mColTxtNor, 9, 0, "Courier New")
    UserControl.Font = "Courier New"
    UserControl.FontSize = 9
    
    Call GetTextMetrics(pic.hdc, tm)
    anccarP = tm.tmAveCharWidth  'Siempre en pixels
    altcarP = tm.tmHeight        'Siempre en pixels
    
    maxTamLin = 0   'no hay l�neas cargadas a�n
    VScroll1.Min = 1
    HScroll1.Min = 1
    pintando = False
    
    'inicia cursor
    curXt_ant = 1
    curYt_ant = 1
    FijaCursor 1, 1
    curXd = 1     'Inicia posici�n X deseada de cursor
    Call FijarSel0  'inicia par�metros de selecci�n
    ActivarCursor
    Call InicDeshacer
    Call InicBuscar("")
    Call InicAyudaContext("")   'Inicia ayuda contextual
    tipArch = 0     'Tipo DOS
    'Posiciones fijas de la barra de estado
    VScroll1.Top = 0
    HScroll1.Left = 0
    
    pic.Top = 0     'Ubica el picture en el control
End Sub

Private Sub UserControl_Terminate()
'Elimina objetos creados
    DeleteObject hPen
    DeleteObject hFont
    DeleteObject hBrush
End Sub

Public Sub Refrescar()
'Actualiza la apriencia y el contenido del control
    Call UserControl_Resize
End Sub

Private Sub pic_Paint()
    'Dibuja sin refrescar PIC para evitar llamadas recursivas
    'Adem�s se supone que si se refresca es porque se ha borrado
    'la informaci�n.
    Call Dibujar(False)
End Sub

Private Sub RecalculaMaxColVis()
'Realiza el Redimensionamiento horizontal, calculando "maxColVis" de acuerdo
'a si se debe mostrar el n�mero de l�nea y aal n�mero de l�neas totales .
Dim ancVScroll As Long
    If verDesVer Then
        ancVScroll = VScroll1.Width
    Else
        ancVScroll = 0
    End If
    If verNumLin Then
        If nlin > 100000 Then
            ancNLinP = 47
        ElseIf nlin > 10000 Then
            ancNLinP = 40
        ElseIf nlin > 1000 Then
            ancNLinP = 33
        ElseIf nlin > 100 Then
            ancNLinP = 26
        Else
            ancNLinP = 19
        End If
    Else
        ancNLinP = 2    'deja un peque�o espacio lateral
    End If
    'posiciona el "pic"
    pic.Left = ancNLinP
    pic.Width = Posit(ScaleWidth - ancVScroll - ancNLinP)
    maxColVis = pic.Width \ anccarP
    col2 = col1 + maxColVis - 1     'actualiza col2
End Sub

Private Sub UserControl_Resize()
Dim altHScroll As Single   'alto de HScroll1
Dim altEstado As Single   'alto de HScroll1
Dim ancVScroll As Single  'ancho de VScroll1
    'Fija ancho de Barra de desplazamiento horizontal
    If verDesVer Then
        HScroll1.Width = Posit(ScaleWidth - VScroll1.Width)
    Else
        HScroll1.Width = ScaleWidth
    End If
    'si se quiere dejar espacio para algo
    'HScroll1.Width = Posit(ScaleWidth - VScroll1.Width - 500)
    'Posici�n de barra de desplazamiento vertical
    If verDesVer Then
        VScroll1.Height = ScaleHeight
        ancVScroll = VScroll1.Width
        VScroll1.Left = ScaleWidth - ancVScroll
        VScroll1.Visible = True
    Else
        ancVScroll = 0
        VScroll1.Visible = False
    End If
    Call RecalculaMaxColVis
    'Redimensionamiento vertical
    If verDesHor Then
        altHScroll = HScroll1.Height
        'a�n no se sabe la posici�n vertical de HScroll1
        HScroll1.Visible = True
    Else
        altHScroll = 0
        HScroll1.Visible = False
    End If
    altEstado = 0
    pic.Height = Posit(ScaleHeight - altHScroll - altEstado)
    'pic.Left = ancNLinP
    'pic.Width = Posit(ScaleWidth - ancVScroll - ancNLinP)
    HScroll1.Top = pic.Height
    'm�ximo que se puede mostrar
    maxLinVis = pic.ScaleHeight \ altcarP
    If maxLinVis = 0 Then
        Exit Sub  'Probablemente minimizado o demasiado peque�o
    End If
    fil2 = fil1 + maxLinVis - 1
    Call ActualizaNLinFin   'actualiza las l�neas visible
    Call Dibujar            'refresca por si acaso. Aqu� se puede cambiar el
                            'dimensionamiento horizontal
    Call ActLimitesBarDesp  'actualiza l�mites de Scroll Bar's
End Sub

Private Sub pic_KeyDown(KeyCode As Integer, Shift As Integer)
Dim conShift As Boolean
Dim conCtrl As Boolean
    RaiseEvent KeyDown(KeyCode, Shift)  'dispara evento
    If KeyCode = 67 And Shift = 4 Then
        RaiseEvent CambiaModo   'Petici�n de cambio de modo
    End If
    If KeyCode = 16 Then Exit Sub   'Ignora <Shift> solo
    If KeyCode = 17 Then Exit Sub   'Ignora <Ctrl> solo
    If KeyCode = 18 Then Exit Sub   'Ignora <Alt> solo
    If (Shift And 1) = 1 Then conShift = True
    If (Shift And 2) = 2 Then conCtrl = True
    If AyudContextKeyDown(KeyCode, Shift) Then
        'No procesamos la tecla porque ya lo proces� el men� de ayuda
        Exit Sub
    End If
    Select Case KeyCode
    'Teclas de desplazamiento
    Case 39 'flecha derecha
        If conCtrl Then    'Ctrl
            DesplazaCursor DIR_DERPAL, , conShift
        Else
            DesplazaCursor DIR_DER, , conShift
        End If
    Case 37 'flecha izquierda
        If conCtrl Then    'Ctrl
            DesplazaCursor DIR_IZQPAL, , conShift
        Else
            DesplazaCursor DIR_IZQ, , conShift
        End If
    Case 40 'flecha abajo
        If conCtrl Then
            DesplazaCursor DIR_ABAPAR, , conShift
        Else
            DesplazaCursor DIR_ABA, , conShift
        End If
    Case 38 'flecha arriba
        If conCtrl Then
            DesplazaCursor DIR_ARRPAR, , conShift
        Else
            DesplazaCursor DIR_ARR, , conShift
        End If
    Case 34     'pag.abajo
        DesplazaCursor DIR_PABA, maxLinVis - 1, conShift
    Case 33     'pag.arriba
        DesplazaCursor DIR_PARR, maxLinVis - 1, conShift
    Case 36     'inicio
        If conCtrl Then    'Ctrl
            DesplazaCursor DIR_HOM, , conShift
        Else
            DesplazaCursor DIR_INI, , conShift
        End If
    Case 35     'fin
        If conCtrl Then    'Ctrl
            DesplazaCursor DIR_END, , conShift
        Else
            DesplazaCursor DIR_FIN, , conShift
        End If
    Case 116    'F5 refresca
        Call Dibujar    'Dibuja el control
    'de modificaci�n
    Case 46     'DEL
        If conShift Then
            Call CortaSeleccion
        Else
            Call CurEliminar
        End If
    Case 45     'INSERT
        If conCtrl Then
            Call CopiaSeleccion
        ElseIf conShift Then
            Call PegaSeleccion
        End If
    Case 13
        
        CurInsertar vbCrLf
    Case 8
        Call CurEliminarB
    End Select
    Call AyudContextKeyDown2(KeyCode, Shift)
End Sub

Private Sub pic_KeyPress(KeyAscii As Integer)
'Procesa una tecla pulsada
    
    If KeyAscii >= 32 Or KeyAscii = 9 Then
'        If Not HayAyudC Then
            CurInsertar Chr(KeyAscii)
'        End If
    End If
'    If KeyAscii = 27 And Not HayAyudC Then
'        RaiseEvent TeclaEscape  'Evento de escape
'    End If
    Call AyudContextKeyPress(KeyAscii)
End Sub

'*************************************************************************************
'************************ FUNCIONES DEL MEN� DE AYUDA CONTEXTUAL *********************
'*************************************************************************************
Public Sub InicAyudaContext(cad_con As String)
'Inicia el motor de ayuda contextual
Dim nar As Integer
    nFilAyudC = 5   'N�mero de filas en el men� contextual
    ListandoTab = False
    ArcListaTab = App.Path & "\lista.lst"
    ReDim ListaTablas(0)
    ReDim IdentAyudC(0)     'Inicia identificadores
End Sub

Private Sub ExcribeElem(matcad() As String, nele As Integer, elem As String)
'Escribe elemento en matriz de cadena, verificando l�mite.
    If nele > UBound(matcad) Then
        'Falt� espacio
        ReDim Preserve matcad(nele + 100)
    End If
    'Escribe elemento
    matcad(nele) = elem
    nele = nele + 1 'actualiza �ndice
End Sub

Private Sub LlenaIdenAyudContextual(Optional agregar As Boolean = False)
'Llena las palabras reservadas. Si "agregar" es TRUE, no se limpia la lista.
Dim n As Integer
    If agregar Then n = UBound(IdentAyudC) + 1 Else n = 1
    ExcribeElem IdentAyudC, n, "ALUMINIO"
    ExcribeElem IdentAyudC, n, "ANTIMONIO"
    ExcribeElem IdentAyudC, n, "AMERICIO"
    ExcribeElem IdentAyudC, n, "AZUFRE"
    ExcribeElem IdentAyudC, n, "BARIO"
    ExcribeElem IdentAyudC, n, "BERKELIO"
    ExcribeElem IdentAyudC, n, "BERILIO"
    ExcribeElem IdentAyudC, n, "BORO"
    ExcribeElem IdentAyudC, n, "CADMIO"
    ExcribeElem IdentAyudC, n, "CALCIO"
    ExcribeElem IdentAyudC, n, "CARBONO"
    ExcribeElem IdentAyudC, n, "CLORO"
    ExcribeElem IdentAyudC, n, "ERBIO"
    ExcribeElem IdentAyudC, n, "ESTA�O"
    ExcribeElem IdentAyudC, n, "FLUOR"
    ExcribeElem IdentAyudC, n, "F�SFORO"
    ExcribeElem IdentAyudC, n, "HELIO"
    ExcribeElem IdentAyudC, n, "HIDR�GENO"
    ExcribeElem IdentAyudC, n, "HIERRO"
    ExcribeElem IdentAyudC, n, "INDIO"
    ExcribeElem IdentAyudC, n, "ITERBIO"
    ExcribeElem IdentAyudC, n, "ITRIO"
    ExcribeElem IdentAyudC, n, "LITIO"
    ExcribeElem IdentAyudC, n, "LUTECIO"
    ExcribeElem IdentAyudC, n, "MAGNESIO"
    ExcribeElem IdentAyudC, n, "MERCURIO"
    ExcribeElem IdentAyudC, n, "MOLIBDENO"
    ExcribeElem IdentAyudC, n, "NE�N"
    ExcribeElem IdentAyudC, n, "NITR�GENO"
    ExcribeElem IdentAyudC, n, "ORO"
    ExcribeElem IdentAyudC, n, "OX�GENO"
    ExcribeElem IdentAyudC, n, "PALADIO"
    ExcribeElem IdentAyudC, n, "PLATA"
    ExcribeElem IdentAyudC, n, "PLATINO"
    ExcribeElem IdentAyudC, n, "PLOMO"
    ExcribeElem IdentAyudC, n, "PLUTONIO"
    ExcribeElem IdentAyudC, n, "RADIO"
    ExcribeElem IdentAyudC, n, "RAD�N"
    ExcribeElem IdentAyudC, n, "SELENIO"
    ExcribeElem IdentAyudC, n, "SILICIO"
    ExcribeElem IdentAyudC, n, "SODIO"
    ExcribeElem IdentAyudC, n, "TANTALIO"
    ExcribeElem IdentAyudC, n, "TECNECIO"
    ExcribeElem IdentAyudC, n, "TITANIO"
    ExcribeElem IdentAyudC, n, "TUNGSTENO"
    ExcribeElem IdentAyudC, n, "URANIO"
    ExcribeElem IdentAyudC, n, "VANADIO"
    ExcribeElem IdentAyudC, n, "XEN�N"
    ExcribeElem IdentAyudC, n, "ZINC"
    ExcribeElem IdentAyudC, n, "ZIRCONIO"
    ExcribeElem IdentAyudC, n, "Lista de Elementos" & vbCrLf & _
                               "<elemento1>," & vbCrLf & _
                               "<elemento2> " & vbCrLf & _
                               "<elemento3> " & vbCrLf & _
                               "Fin Lista."
    ReDim Preserve IdentAyudC(n)    'Elimina valores no usados
End Sub



Private Sub lstCont_KeyPress(KeyAscii As Integer)
    If KeyAscii = 27 Then
        Call FinAyudContextual
    End If
End Sub

Private Function anchoMaxLista() As Long
'Devuelve el ancho m�ximo del texto en la lista lstCont
Dim i As Integer
Dim anc As Single
Dim cad As String
Dim tx As SIZE
Dim lHDC As Long
    lHDC = GetDC(lstCont.hWnd)  'toma DC
    For i = 0 To lstCont.ListCount - 1
        cad = lstCont.List(i)
        Call GetTextExtentPoint32(lHDC, cad, Len(cad), tx)
        If tx.cx > anc Then anc = tx.cx
    Next
    anchoMaxLista = anc
End Function

Private Sub AbreAyudContextual(xtIni As Integer, ytIni As Long)
Const ALT_MIN_CON = 70     'Alto m�nimo de men� contextual (aprox. 5 l�neas)
Const ANC_MIN_CON = 100    'Ancho m�nimo de men� contextual
Const ANC_MAX_CON = 200    'Ancho m�nimo de men� contextual
    'Verifica si se puede iniciar ayuda contextual
    If xtIni < 1 Or ytIni < 1 Then Exit Sub
    If UserControl.Height < ALT_MIN_CON + altcarP Then
        Exit Sub
    End If
    If UserControl.Width < ANC_MIN_CON Then
        Exit Sub
    End If
    altMenCon = ALT_MIN_CON
    'calcula el ancho a mostrar de acuerdo a los �tems
    ancMenCon = anchoMaxLista()
    If ancMenCon < ANC_MIN_CON Then ancMenCon = ANC_MIN_CON
    If ancMenCon > ANC_MAX_CON Then ancMenCon = ANC_MAX_CON
    'Este truco se hace para ver cual es la mayor altura
    'del listbox que contiene l�neas completas
    lstCont.Height = altMenCon    '
    altMenCon = lstCont.Height
    'guarda posici�n de inicio
    xtIniIden = xtIni
    ytIniIden = ytIni   'guarda posici�n de inicio
    'Calcula posici�n horizontal
    xCont0 = anccarP * (curXt - col1 + 1)
    If xCont0 + ancMenCon > UserControl.Width Then
        xCont0 = UserControl.Width - ancMenCon
    End If
    'Calcula posici�n vertical
    yCont0 = altcarP * (curYt - fil1 + 1)
    If yCont0 + altMenCon > UserControl.Height Then
        yCont0 = yCont0 - altMenCon
        If yCont0 < 0 Then Exit Sub     'Escap� de la pantalla
    End If
    '-------------- Finalmente activa la ayuda contextual ----------
    'Asigna propiedades
    lstCont.Left = xCont0
    lstCont.Top = yCont0
    'lstCont.Height = altMenCon 'ya se asign�
    lstCont.Width = ancMenCon
    lstCont.Visible = True
    HayAyudC = True     'Marca bandera
End Sub

Private Sub FinAyudContextual()
    'termina ayuda contextual
    lstCont.Visible = False
    HayAyudC = False    'Marca bandera
End Sub

Private Function AyudContextKeyDown(KeyCode As Integer, Shift As Integer) As Boolean
'Procesa el evento KeyDown para el men� de ayuda contextual
'Si la tecla ha sido procesada, devuelve verdadero
Dim i As Integer
    'Si no est� activa la ayuda contextual, se sale
    If Not HayAyudC Then Exit Function
    i = lstCont.ListIndex
    'Identifica la tecla
    Select Case KeyCode
    'Teclas de desplazamiento
    Case 39 'flecha derecha
    Case 37 'flecha izquierda
    Case 40 'flecha abajo
        If i < lstCont.ListCount - 1 Then lstCont.ListIndex = i + 1
        AyudContextKeyDown = True
    Case 38 'flecha arriba
        If i = 0 Then   'Pasa a abajo
            If lstCont.ListCount > 0 Then lstCont.ListIndex = lstCont.ListCount - 1
        ElseIf i > 0 Then
            lstCont.ListIndex = i - 1
        End If
        AyudContextKeyDown = True
    Case 34  'pag.abajo
        If i < lstCont.ListCount - nFilAyudC Then
            lstCont.ListIndex = i + nFilAyudC
        Else
            If lstCont.ListCount > 0 Then lstCont.ListIndex = lstCont.ListCount - 1
        End If
        AyudContextKeyDown = True
    Case 33  'pag.arriba
        If i > nFilAyudC Then
            lstCont.ListIndex = i - nFilAyudC
        Else
            If lstCont.ListCount > 0 Then lstCont.ListIndex = 0
        End If
        AyudContextKeyDown = True
    Case 36  'inicio
    Case 35  'fin
    Case 46  'DEL
    Case 45  'INSERT
    Case 13
        AyudContextKeyDown = True   'Captura el enter
    End Select
End Function

Private Sub AyudContextKeyDown2(KeyCode As Integer, Shift As Integer)
'Procesa el evento KeyDown para el men� de ayuda contextual
'Debe llamarse despu�s de que el editor ha procesado el evento, para tener
'el estado final del editor
Dim i As Integer
    'Si no est� activa la ayuda contextual, se sale
    If Not HayAyudC Then Exit Sub
    'Verifica condiciones de t�rmino
    If curXt < xtIniIden Then
        Call FinAyudContextual
        Exit Sub
    End If
    If curYt <> ytIniIden Then
        Call FinAyudContextual
        Exit Sub
    End If
    i = lstCont.ListIndex
    'Identifica la tecla
    Select Case KeyCode
    'Teclas de desplazamiento
    Case 39 'flecha derecha
    Case 37 'flecha izquierda
    Case 36  'inicio
        AyudContextKeyPress 0   'S�lo Para validaci�n
    Case 35  'fin
        AyudContextKeyPress 0   'S�lo Para validaci�n
    Case 46  'DEL
        AyudContextKeyPress 0   'S�lo Para validaci�n
    Case 45  'INSERT
        AyudContextKeyPress 0   'S�lo Para validaci�n
    End Select
End Sub

Private Function CarAnterior(cad As String, pos As Integer) As String
'Devuelve el caracter anterior a una posici�n en una cadena
'Todos los caracteres se devuelven en may�scula
    If pos > 1 Then
        CarAnterior = UCase(Mid$(cad, pos - 1, 1))
    Else
        CarAnterior = ""
    End If
End Function

Private Function CarActual(cad As String, pos As Integer) As String
'Devuelve el caracter actual en la posici�n en una cadena
'Todos los caracteres se devuelven en may�scula
    If pos <= Len(cad) Then
        CarActual = UCase(Mid$(cad, pos, 1))
    Else
        CarActual = ""
    End If
End Function

Private Function LeePrimerosCar(xt As Integer, yt As Long) As String
'Obtiene la parte de una l�nea anterior a una posici�n.
'Se eliminan tabulaciones, espacios m�ltiples y se convierte a may�scula
Dim p As Tpostex
Dim lin As String
    If xt <= 1 Then Exit Function
    lin = Left$(linrea(yt), xt - 1) 'toma parte anterios
    lin = Replace(lin, vbTab, " ")  'convierte tabulaciones
    lin = UCase(Trim(lin))          'convierte a may�scula
    lin = Replace(lin, "  ", " ")   'elimina espacios m�ltiples, OJO!!!!, no es 100% seguro
    LeePrimerosCar = lin
End Function

Private Sub AyudContextKeyPress(KeyAscii As Integer)
'Procesa el evento KeyPress para el men� de ayuda contextual
Dim c As String
Dim xIniId As Integer   'Posici�n Inicial de Identificador
Dim lin As String       'L�nea de trabajo
Dim iden As String      'Identificador
Dim i As Integer
Dim ncar As Long
    'Verifica condici�n de fin
    If KeyAscii = 27 Or KeyAscii = 32 Then
        If HayAyudC Then FinAyudContextual   '... Hab�a
        Exit Sub
    End If
    If (KeyAscii = 9 Or KeyAscii = 13) And HayAyudC Then
        'Se acepta la opci�n del men� contextual
        i = lstCont.ListIndex   'lee opci�n
        If i <> -1 Then
            'Hay item seleccionado
            'Se selecciona el identificador a reemplazar
            ncar = PosXTreal(curXt, curYt) - xtIniIden
            SelecIdentificador xtIniIden, curYt, ncar
            CurInsertar lstCont.List(i)
        End If
        FinAyudContextual   'Termina la ayuda contextual
        Exit Sub
    End If
    'Procesa el comportamiento
    If HayAyudC Then     'Ya hay men� contextual...
        'toma identificador
        i = PosXTreal(curXt, curYt) 'Guarda posici�n actual
        If i <= xtIniIden Then  'Puede que se haya retrocedido
            FinAyudContextual
            Exit Sub
        End If
        iden = Mid$(linrea(ytIniIden), xtIniIden, i - xtIniIden)
        If Len(iden) < 1 Then
            FinAyudContextual   'Termina la ayuda contextual
            Exit Sub
        End If
    Else            'No hab�a men� contextual
        'Verifica condiciones para activarlo
        c = UCase(Chr(KeyAscii))
        If c Like CAR_IDEN_VALM Then
            'Busca inicio de identificador
            lin = linrea(curYt) 'lee l�nea
            If CarActual(lin, curXt) Like CAR_IDEN_VALM Then
                Exit Sub    'Estamos en medio de un identificador
            End If
            i = PosXTreal(curXt, curYt) 'Guarda posici�n actual
            xIniId = i
            Do While xIniId > 1 And CarAnterior(lin, xIniId) Like CAR_IDEN_VALM
                xIniId = xIniId - 1
            Loop
            'verifica identificador previo
            iden = Mid$(linrea(curYt), xIniId, i - xIniId)
            'Verifica si se cumplen condiciones
            If Len(iden) < 1 Then Exit Sub
            'Llena la lista para verificar
            lin = LeePrimerosCar(xIniId, curYt)   'lee l�nea a comparar, por si la necesita
            
            'Llena lista de identificadores. Aqu� pdor�a elegirse la lista a usar, dependiendo
            'del contexto.
            Call LlenaIdenAyudContextual
            
            Call ListaIdenAyudCont(iden)
            If lstCont.ListCount = 0 Then Exit Sub  'No hay coincidencias
            'Inicia finalmente
            Call AbreAyudContextual(xIniId, curYt)
            Exit Sub 'y sale
        End If
    End If
    If Not HayAyudC Then Exit Sub    'No hay men�, salir
    Call ListaIdenAyudCont(iden)
    If lstCont.ListCount = 0 Then FinAyudContextual  'No hay coincidencias
End Sub

Private Sub ListaIdenAyudCont(iden As String)
'Genera una lista de identificadores similares a un identificador
Dim i As Integer
    lstCont.Clear
'    lstCont.AddItem iden
    iden = UCase(iden)
    For i = 1 To UBound(IdentAyudC)
        If UCase(IdentAyudC(i)) Like iden & "*" Then
            lstCont.AddItem IdentAyudC(i)
        End If
    Next
    If lstCont.ListCount > 0 Then
        lstCont.ListIndex = 0   'selecciona el primero
    End If
End Sub

'-----Eventos del desplazamiento
Private Sub VScroll1_Change()
Dim dy As Long
    If pintando Then Exit Sub   'Se est� en medio de un redibujo
    dy = VScroll1.Value / facdesV - fil1
    FijaFil1 fil1 + dy
    Call Dibujar    'Dibuja el control
End Sub

Private Sub HScroll1_Change()
Dim dx As Integer
    If pintando Then Exit Sub   'Se est� en medio de un redibujo
    dx = HScroll1.Value - col1
    FijaCol1 col1 + dx  'desplaza
    Call Dibujar    'Dibuja el control
End Sub

'*************************************************************************************
'****************** FUNCIONES GR�FICAS Y DE DESPLAZAMIENTO DEL CURSOR ****************
'*************************************************************************************
Private Sub FijaLapiz(estilo As Long, ancho As Long, color As Long)
'Establece el l�piz actual de dibujo
Dim hdc As Long
    hdc = pic.hdc
    If hPen <> 0 Then DeleteObject hPen     'si ya hay un l�piz, lo elimina
    hPen = CreatePen(estilo, ancho, color)
    SelectObject hdc, hPen                  'queda pendiente eliminarlo
End Sub

Private Sub FijaRelleno(colorr As Long)
'Establece el relleno actual
Dim hdc As Long
    hdc = pic.hdc
    If hBrush <> 0 Then DeleteObject hBrush 'si hay relleno, lo elimina
    hBrush = CreateSolidBrush(colorr)
    SelectObject hdc, hBrush                'queda pendiente eliminarlo
End Sub

Private Sub FijaTexto(color As Long, tam As Long, nDegrees As Single, _
              Optional Letra As String = "Times New Roman", _
              Optional negrita As Boolean = False, _
              Optional cursiva As Boolean = False, _
              Optional subrayado As Boolean = False)
    pic.ForeColor = color
    pic.Font.SIZE = tam
    pic.Font.Name = Letra
End Sub

Private Sub DesplazaCursor(direccion As Integer, Optional paso As Long = 1, _
                           Optional actselec As Boolean = False)
'Mueve el cursor en la pantalla, considerando que deba caer en una posici�n
'v�lida. Desplaza y refresca la pantalla si es necesario
'Implementado a responder los desplazamientos por teclado. Se ha dise�ado
'para que los rerfrescos de pantalla sean s�lo cuando es necesario.
Dim posi As Integer 'posici�n inicial
Dim lin As String   'linea de trabajo
    Redibujar = False       'inicia para verificar si se debe redibujar
    'Verifica si escapa de la pantalla o de zona v�lida
    Select Case direccion
    Case DIR_IZQ
        If curXt = 1 And curYt > 1 Then   'Esta al inicio de l�nea y hay anterior
            tCursorA2 Len(linexp(curYt - 1)) + 1, curYt - 1, A_IZQ_TAB
        Else
            tCursorA2 curXt - paso, curYt, A_IZQ_TAB
        End If
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_DER
        If curXt >= Len(linact) + 1 And curYt < nlin Then  'Final de l�nea y hay siguiente
            tCursorA2 1, curYt + 1, A_DER_TAB
        Else
            tCursorA2 curXt + paso, curYt, A_DER_TAB
        End If
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_ARR
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        tCursorA2 curXt, curYt - paso, A_IZQ_TAB
    Case DIR_ABA
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        tCursorA2 curXt, curYt + paso, A_IZQ_TAB
    Case DIR_PARR   'P�gina arriba
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        VerticalScroll CInt(-paso)
        tCursorA2 curXt, curYt - paso, A_IZQ_TAB
    Case DIR_PABA   'P�gina abajo
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        VerticalScroll CInt(paso)
        tCursorA2 curXt, curYt + paso, A_IZQ_TAB
    Case DIR_ARRPAR
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        tCursorA2 curXt, curIniPar(), A_IZQ_TAB
    Case DIR_ABAPAR
        If curXd <> curXt Then curXt = curXd  'intenta recuperar posici�n
        tCursorA2 curXt, curFinPar(), A_IZQ_TAB
    Case DIR_INI    'lleva hasta el inicio de la l�nea
        tCursorA 1, curYt, A_IZQ_TAB
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_FIN    'lleva hasta el final de la l�nea
        tCursorA maxTamLin + 1, curYt, A_DER_TAB
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_HOM    'Al inicio del texto
        tCursorA 1, 1, A_IZQ_TAB
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_END    'Al final del texto
        tCursorA2 maxTamLin + 1, nlin, A_IZQ_TAB
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_IZQPAL
        If curXt = 1 And curYt > 1 Then   'Esta al inicio de l�nea y hay anterior
            tCursorA2 Len(linexp(curYt - 1)) + 1, curYt - 1, A_IZQ_TAB
        Else
            tCursorA2 curIniPal(), curYt, A_IZQ_TAB
        End If
        curXd = curXt     'actualiza posici�n deseada
    Case DIR_DERPAL 'A la derecha por palabra
        If curXt >= Len(linact) + 1 And curYt < nlin Then  'Final de l�nea y hay siguiente
            tCursorA2 1, curYt + 1, A_DER_TAB
        Else
            tCursorA2 curSigPal(), curYt, A_IZQ_TAB
        End If
        curXd = curXt      'actualiza posici�n deseada
    End Select
    'Procesa el dibujo de la selecci�n
    If actselec Then    'Activar selecci�n
        Call ExtenderSel
    Else
        If Redibujar Then   'Se movi� la pantalla, redibujamos todo
            Call LimpSelec  'Aprovechamos para limpiar si hay selecci�n
            Call Dibujar
        Else
            Call LimpSelec(True)      'Limpia selecci�n
        End If
        'Marca la posici�n del cursor antes de una selecci�n
        Call FijarSel0      'Fija punto base
        Call EncenCursor    'Enciende para que sea visible en la nueva posici�n
    End If
End Sub

Private Sub ExtenderSel()
'Refresca el texto del control considerando que la posici�n actual del cursor define
'un l�mite (inicial o final) en el bloque de selecci�n. El otro l�mite es "sel0" que
'debe haber sido previamente fijado.
'Lo que se trata de hacer con este procedimiento es evitar llamar innecesariamente
'a Dibujar(). Pero si la variable "Redibujar" est� en true, se redibuja todo
'incondicionalmente.
Dim Ptmp As Tpostex      'define el intervalo de la zona a dibujar
    If tipSelec = 1 Then Redibujar = True   'Fuerza actualizaci�n Total en este modo
    Call DesactivarCursor   'Se desactiva para no interferir
    haysel = True   'se marca la bandera
    If CurMenorPos(sel0) Then   '--------Cursor antes de sel0---------
        If MayorPos(sel2, sel0) Then    'Pas� de despu�s a antes
            Ptmp = sel2     'guarda l�mite de dibujo
            sel1 = LeePosCur()    'Inicio de la selecci�n est� ahora en el cursor
            sel2 = sel0
            If Redibujar Then Call Dibujar Else Call DibTextPos(sel1, Ptmp)
        Else 'Selecci�n sigue de Cursor a sel0 (s�lo aumenta o disminuye)
            sel1 = LeePosCur()     'Inicio de la selecci�n est� ahora en el cursor
            sel2 = sel0
            'Verifica si se dibuja todo o s�lo las l�neas afectadas
            If Redibujar Then Call Dibujar Else Call DibTextPos(sel1, sel1ant)
        End If
    ElseIf CurMayorPos(sel0) Then   '--------Cursor despu�s de sel0---------
        If MenorPos(sel1, sel0) Then 'Pas� de antes a despu�s.
            Ptmp = sel1     'guarda l�mite de dibujo
            sel1 = sel0
            sel2 = LeePosCur()     'Fin de la selecci�n est� ahora en el cursor
            If Redibujar Then Call Dibujar Else Call DibTextPos(Ptmp, sel2)
        Else 'Selecci�n sigue de sel0 a Cursor (s�lo aumenta o disminuye)
            sel1 = sel0
            sel2 = LeePosCur()    'Fin de la selecci�n est� ahora en el cursor
            'Verifica si se dibuja todo o s�lo las l�neas afectadas
            If Redibujar Then Call Dibujar Else Call DibTextPos(sel2, sel2ant)
        End If
    Else            '--------Cursor en la misma posici�n---------
        'No hay nada que procesar, s�lo ver si hay que borrar
        sel1 = sel0
        sel2 = sel0
        If Redibujar Then Call Dibujar Else Call DibTextPos(sel1ant, sel2ant)
    End If
    'actualiza anteriores
    sel1ant = sel1
    sel2ant = sel2
End Sub

Public Sub VerticalScroll(dy As Integer)
'Funci�n p�blica para realizar un desplazamiento vertical de la pantalla.
'Se ha creado pensando en el desplazamiento con el evento "MouseWheel"
Dim vFinal As Integer
    vFinal = VScroll1.Value + dy
    If vFinal > VScroll1.Max Then vFinal = VScroll1.Max
    If vFinal < VScroll1.Min Then vFinal = VScroll1.Min
    VScroll1.Value = vFinal
End Sub
