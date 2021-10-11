unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,math;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormResize(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;
  palette:array[0..360] of longint;
  bt:tbitmap;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
var
i:integer;
begin
 // on crée la palette de couleur pour l'affichage
 for i:=0 to 360 do
   Case (i div 60) of
      0,6:palette[i]:=rgb(255,(i Mod 60)*255 div 60,0);
      1: palette[i]:=rgb(255-(i Mod 60)*255 div 60,255,0);
      2: palette[i]:=rgb(0,255,(i Mod 60)*255 div 60);
      3: palette[i]:=rgb(0,255-(i Mod 60)*255 div 60,255);
      4: palette[i]:=rgb((i Mod 60)*255 div 60,0,255);
      5: palette[i]:=rgb(255,0,255-(i Mod 60)*255 div 60);
   end;
 bt:=tbitmap.Create;
 bt.PixelFormat:=pf32bit;
end;


//=================================
type
 TBuffer=array[0..3] of extended;
 Pbuffer=^tbuffer;


// calcul la racine cubique sans bug pour les nombres négatifs
function radcubique(nb:double):double;
begin
 if nb>0 then
  result:=power(nb,1.0/3.0)
 else
  result:=-power(-nb,1.0/3.0);
end;


//Resolution d'une équation du deuxieme degré
function Deuxiemedegre(a,b,c:double;buffer:pbuffer):integer;
var
 delta:double;
begin
 // pas de solution
 if (a=0) and (b=0) then
  begin
   result:=0;
   exit;
  end;
 // une seule solution
 if (a = 0) then
  begin
   buffer[0] := -c/b;
   result:=1;
   exit;
  end;
 // calcul du déterminant
 delta := b*b-4*a*c;
 // positif, deux racines dans R
 if (delta>0) then
  begin
   buffer[0] := (-b-sqrt(delta))/(2*a);
   buffer[1] := (-b+sqrt(delta))/(2*a);
   result:=2;
  end
 else // delta=0, une seule racine double
 if (delta=0) then
  begin
   buffer[0] := -b/(2*a);
   result:=1;
  end
 else result:=0;
end;

// Resolution d'une équation du troisième degré, retourne le nombre de racines
// Méthode de Cardan
// je passe les détails...
function Troisiemedegre(a,b,c,d:double;buffer:pbuffer):integer;
var
 t,r,arg,p,q,delta:double;
 i:integer;
begin
 if (a = 0) then // cas d'une équation du second degré
  begin
   result:=Deuxiemedegre(b,c,d,buffer);
   exit;
  end;
 p := (-b*b)/(3*a*a) + c/a;
 q := (2*b*b*b)/(27*a*a*a) - (b*c)/(3*a*a) + d/a;

 delta := q*q+4*p*p*p/27.0;

 if (delta>0) then
  begin
   buffer[0] := radcubique(-q/2.0+sqrt(delta)/2.0)+radcubique(-q/2.0-sqrt(delta)/2.0);
   buffer[0] := buffer[0] -b/(3*a);
   result:= 1;
  end
 else
 if (delta = 0) then
  begin
   buffer[0]:=radcubique(-4*q)  -b/(3*a);
   buffer[1]:=-radcubique(-4*q)/2  -b/(3*a);
   result:=2;
  end
 else //delta<0
  begin
   arg := -q/(2*sqrt(-p*p*p/27));
   t := arccos(arg);
   result:= 3;
   for i:=0 to 2 do
    begin
     buffer[i] := 2*sqrt(-p/3)*cos((t+2*i*PI)/3.0) - b/(3*a);
    end;
  end;
end;

procedure swapval(var x,y:integer);overload;
var
 tmp:integer;
begin
 tmp:=x;
 x:=y;
 y:=tmp;
end;

procedure swapval(var x,y:extended);overload;
var
 tmp:extended;
begin
 tmp:=x;
 x:=y;
 y:=tmp;
end;

//===================================


// structure qui va recevoir les infos sur chaque portion de courbe
type
 tParambezier=record
               aa,bb,cc,dd:record x,y:extended; end; // équation du 3ième degré d'arc bezier
               t1,t2:extended;                       // interval de la variable t de l'équation
               p1,p2:tpoint;                         // extrémité de l'arc
               decalage:integer;                     // y varie entre p1.y et p2.y alors que le tableau limite varie entre 0 et nligne => décalage
               nligne:integer;                       // nombre de ligne suivant Y qu'occupe l'arc
               limite:array of tpoint;               // limite du segment (en fonction de chaque ligne) x=mini  y=maxi
              end;

var
 s:tbuffer;
 NumArcBezier:integer=0;
 listeArcBezier:array of tParambezier;



// ajoute l'arc de bezier à la liste
//==============================================================================
procedure AddBezier(b:TParamBezier);
var
 i,j,x,y:integer;
 s:tbuffer;
begin
 //on augmente la taille de la liste
 inc(NumArcBezier);
 setlength(listeArcBezier,NumArcBezier);
 listeArcBezier[NumArcBezier-1]:=b;
 listeArcBezier[NumArcBezier-1].nligne:=abs(b.p2.y-b.p1.y)+1;
 // on cherche maintenant toutes les solutions de l'équation pour
 // avoir tout les points de l'arc
 // comme c'est un arc sans changement de direction, chaque ligne
 // ne contient qu'un segment plus ou moins long de pixels collés les uns aux autres
 with listeArcBezier[NumArcBezier-1] do
 begin
 decalage:=min(p1.Y,p2.Y);
 setlength(limite,nligne);
 for i:=0 to nligne-1 do limite[i].X:=999999;
 for i:=0 to nligne-1 do limite[i].Y:=-999999;

 // suivant Y
 if p2.y<>p1.y then
     for i:=min(p1.Y,p2.Y) to max(p1.Y,p2.Y) do
      begin
       j:=Troisiemedegre(aa.y,bb.y,cc.y,dd.y-i,@s);
       for j:=0 to j-1 do if (s[j]>=t1) and (s[j]<=t2) then
        begin
         x:=round(dd.x+cc.x*s[j]+bb.x*s[j]*s[j]+aa.x*s[j]*s[j]*s[j]);
         limite[i-decalage].X:=min(limite[i-decalage].x,x);
         limite[i-decalage].Y:=max(limite[i-decalage].y,x);
        end;
      end;
  // et suivant X pour être sur de rien rater...
  if p2.x=p1.x then
   begin
    for i:=0 to nligne-1 do limite[i]:=point(p1.x,p1.x);;
   end
  else
     for i:=min(p1.x,p2.x) to max(p1.x,p2.x) do
      begin
       j:=Troisiemedegre(aa.x,bb.x,cc.x,dd.x-i,@s);
       for j:=0 to j-1 do if (s[j]>=t1) and (s[j]<=t2) then
        begin
         y:=round(dd.y+cc.y*s[j]+bb.y*s[j]*s[j]+aa.y*s[j]*s[j]*s[j]);
         limite[y-decalage].x:=min(limite[y-decalage].x,i);
         limite[y-decalage].y:=max(limite[y-decalage].y,i);
        end;
      end;
 end;
end;



// création et remplissage du tableau des arcs de bezier
//==============================================================================
procedure Precalculsimplespline(pt:array of tpoint);
var
 i,j,k:integer;
 x,y:integer;
 l:integer;
 bezier:tparambezier;

 // tri les solutions de l'équation du second degré dans l'ordre croissant
 // en retirant les solutions <=0 ou >=1
 procedure sortsolution(var s:tbuffer;var n:integer);
 var
  i,j:integer;
  tmp:extended;
 begin
  for j:=0 to n-2 do
   for i:=j+1 to n-1 do
    if s[i]<s[j] then swapval(s[i],s[j]);
  //
  while (n>0) and (s[0]<=0) do begin for i:=0 to 2 do s[i]:=s[i+1]; dec(n); end;
  while (n>0) and (s[n-1]>=1) do dec(n);
 end;

begin
 with bezier do
  begin
   // calcul les coefficients de l'équation du 3ième degré décrivant la courbe de bézier
   // f(t)=aa*t^3+bb*t^2+cc*t+dd avec t dans [0..1]
   dd.x:=   Pt[0].x;
   cc.x:=-3*Pt[0].x+3*Pt[1].x;
   bb.x:= 3*Pt[0].x-6*Pt[1].x+3*Pt[2].x;
   aa.x:=  -Pt[0].x+3*Pt[1].x-3*Pt[2].x+Pt[3].x;

   dd.y:=   Pt[0].y;
   cc.y:=-3*Pt[0].y+3*Pt[1].y;
   bb.y:= 3*Pt[0].y-6*Pt[1].y+3*Pt[2].y;
   aa.y:=  -Pt[0].y+3*Pt[1].y-3*Pt[2].y+Pt[3].y;

   // cherche les points de changement de direction => on dérive f(t)
   // et on cherche f'(t)=0 avec t dans [0..1]
   // en deux fois car suivant X et suivant Y
   l:=Deuxiemedegre(3*aa.y,2*bb.y,cc.y,@s);
   l:=l+Deuxiemedegre(3*aa.x,2*bb.x,cc.x,@s[l]);
   // on tri les solutions
   sortsolution(s,l);
   // on découpe la courbe en arc plus petit, mais ne changeant pas de direction...
   // l'arc va de p1 à p2 en décrivant un arc dont l'équation ai
   // f(t)=aa*t^3+bb*t^2+cc*t+dd avec t dans [t1..t2]
   for i:=0 to l do
    begin
     if i=0 then  t1:=0 else t1:=s[i-1];
     if i=l then  t2:=1 else t2:=s[i];
     p1.x:=round(dd.x+cc.x*t1+bb.x*t1*t1+aa.x*t1*t1*t1);
     p1.y:=round(dd.y+cc.y*t1+bb.y*t1*t1+aa.y*t1*t1*t1);
     p2.x:=round(dd.x+cc.x*t2+bb.x*t2*t2+aa.x*t2*t2*t2);
     p2.y:=round(dd.y+cc.y*t2+bb.y*t2*t2+aa.y*t2*t2*t2);
     addbezier(bezier);
    end;
  end;
end;


// on dessine le contour (dans l'ordre des points suivant la courbe)
//==============================================================================
procedure DrawPenSpline;
var
 i,j,k,cl:integer;
 mode:byte;

 // affiche le point voulu (avec un beau dégradé pour voir l'ordre des points)
 procedure Pset(x,y:integer);
 begin
  bt.Canvas.Pixels[x,y]:=palette[cl];
  cl:=(cl+1) mod 360;
 end;

begin
 cl:=0;
 // la liste des arcs est dans le bon ordre, les arcs vont du point 1 au point 2
 for i:=0 to NumArcBezier-1 do
 with listeArcBezier[i] do
  begin
   mode:=(sign(p2.x-p1.x)+1)+(sign(p2.y-p1.y)+1)*3;
   // suivant le sens de déplacement de l'arc, on n'affiche pas les points dans le
   // même ordre.
   //( de haut en bas, de bas en haut, de gauche à droite ou de droite à gauche...)
   case mode of
    0: //-1,-1
     for j:=nligne-1 downto 0 do for k:=limite[j].y downto limite[j].x do pset(k,j+decalage);
    1: //0,-1 = trait vertical vers le haut
     for j:=p1.y downto p2.y do pset(p1.X,j);
    2://1,-1
     for j:=nligne-1 downto 0 do for k:=limite[j].x to limite[j].y do pset(k,j+decalage);
    3://-1,0  = trait horizontal vers la gauche
     for j:=p1.x downto p2.x do pset(j,p1.Y);
    4://0,0 = juste un point !!!
     pset(p1.X,p1.Y);
    5://1,0   = trait horizontal vers la droite
     for j:=p1.x to p2.x do pset(j,p1.y);
    6://-1,1
     for j:=0 to nligne-1 do for k:=limite[j].y downto limite[j].x do pset(k,j+decalage);
    7://0,1 = trait vertical vers le bas
     for j:=p1.y to p2.y do pset(p1.X,j);
    8://1,1
     for j:=0 to nligne-1 do for k:=limite[j].x to limite[j].y do pset(k,j+decalage);
   end;
  end;
end;


// on dessine le fond
//==============================================================================
procedure DrawbrushSpline;
var
 i,j,k:integer;
 miny,maxy:integer;
 NInter:integer;
 inter:array of integer;
 pt0:tpoint;
 pt1:tpoint;
 pt2:tpoint;

 // affiche le point voulu (en gris)
 procedure Pset(x,y:integer);
 begin
  bt.Canvas.Pixels[x,y]:=clLtGray;
 end;

 // ajoute le point x à la liste des intersections
 procedure addinter(x:integer);
 begin
  inc(NInter);
  setlength(inter,NInter);
  inter[NInter-1]:=x;
 end;

 //cherche les intersections entre la ligne Y et les arcs de bezier
 procedure ChercheInter(y:integer);
 var
  ii,jj:integer;
 begin
  NInter:=0;
  for ii:=0 to NumArcBezier-1 do
   begin
    // les trois points consécutifs
    pt0:=listeArcBezier[(ii+NumArcBezier-1) mod NumArcBezier].p1;
    pt1:=listeArcBezier[ii].p1;
    pt2:=listeArcBezier[ii].p2;

    // l'arc ne coupe pas la ligne, on continue
    if min(pt1.y,pt2.y)>y then continue;
    if max(pt1.y,pt2.y)<y then continue;

    // on est sur un bout de l'arc
    if pt1.y=y then
     begin
      // on regarde comment s'articule les deux arc (avant et présent)
      if ( (sign(pt1.Y-pt0.Y)+1) + (sign(pt2.Y-pt1.Y)+1)*4) in [0,10,4,9] then  addinter(pt1.X);
      continue;
     end;

    // on est sur l'autre bout de l'arc => rien à faire
    if pt2.y=y then continue;


    // on est au milieu de l'arc, on ajoute le point médian
    addinter((listeArcBezier[ii].limite[y-listeArcBezier[ii].decalage].X
             +listeArcBezier[ii].limite[y-listeArcBezier[ii].decalage].Y) div 2);
   end;

  // on tri le tableau
  for jj:=0 to NInter-2 do
   for ii:=jj+1 to NInter-1 do
    if inter[jj]>inter[ii] then swapval(inter[jj],inter[ii]);
 end;

begin
 // on cherche d'abords le mini et le maxi suivant Y
 miny:=bt.Height;
 maxy:=0;
 for i:=0 to NumArcBezier-1 do miny:=min(miny,min(listeArcBezier[i].p1.Y,listeArcBezier[i].p2.Y));
 for i:=0 to NumArcBezier-1 do maxy:=max(maxy,max(listeArcBezier[i].p1.Y,listeArcBezier[i].p2.Y));

 // pour chaque ligne, on cherche les intersections entre la ligne et les arcs
 // puis on colorie les zones entre deux intersections
 for i:=miny to maxy do
  begin
   chercheinter(i);
   for j:=1 to NInter div 2 do for k:=Inter[j*2-2] to Inter[j*2-1] do pset(k,i);
  end;
end;


// fonction principale pour le dessin de la courbe
//==============================================================================
procedure DrawSpline(pt:array of tpoint);
var
 i,j:integer;
 p:array[0..3] of tpoint;
begin
 numarcbezier:=0;
 // on tronçonne en arc de bezier la courbe
 for i:=0 to length(pt) div 3-1 do
  begin
   p[0]:=pt[i*3];
   p[1]:=pt[i*3+1];
   p[2]:=pt[i*3+2];
   p[3]:=pt[i*3+3];
   Precalculsimplespline(p);
  end;
 // on dessine le fond
 DrawbrushSpline;
 // on dessine la bordure
 DrawPenSpline;
end;



// Traitement des messages
//==============================================================================


// mouvement de la souris, on affiche la courbe de bezier
procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
 pt:array of tpoint;
begin
 // on rempli le tableau des points de la courbe
 setlength(pt,10);
 pt[0]:=point(x,y);                                     //point 1
 pt[1]:=point(x-50,y-100);                              //poigné du point 1
 pt[2]:=point(350,350);                                 //poigné du point 2
 pt[3]:=point(450,350);                                 //point 2
 pt[4]:=point(550,350);                                 //poigné du point 2
 pt[5]:=point( 100+x div 2,50+x*y div (x+y));           //poigné du point 3
 pt[6]:=point( 50+x div 2,50+x*y div (x+y));            //point 3
 pt[7]:=point(    x div 2,50+x*y div (x+y));            //poigné du point 3
 pt[8]:=point(x+50,y+100);                              //poigné du point 1
 pt[9]:=point(x,y);                                     //point 1 << on referme la courbe.
                                                        // sinon, gros bug...

 // on efface le bitmap temporaire de dessin
 bt.Canvas.FillRect(clientrect);
 // on y dessine la courbe
 DrawSpline(pt);
 // on affiche le résultat
 canvas.Draw(0,0,bt);
end;

// redimensionnement de la fenêtre => on redimensionne le bitmap temporaire
procedure TForm1.FormResize(Sender: TObject);
begin
 bt.Width:=clientwidth;
 bt.Height:=clientheight;
end;

end.

