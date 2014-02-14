%{
#include <iostream>
#include <string>
#include <sstream>
#include <map>
#include <list>

#define YYSTYPE atributos

using namespace std;

struct atributos
{
	string label;
	string traducao;
	string tipo;
	int tamanho;
};
typedef struct atributos Atributos;

typedef map<string, Atributos> STRINGMAP;

STRINGMAP labelsMap;

int yylex(void);
void yyerror(string);
string generateLabel();
string geraBloco();
string intToString(int label);
int tipoToIndice(string tipo);
void traducaoOpAritmetica(Atributos* dolar, Atributos* um, Atributos* tres, char operador);
void traducaoOpAritmeticaIncDec(Atributos* dolar, Atributos* um, string operador);
void atribuicao (Atributos* dolar, Atributos* um, Atributos* tres);
void logica(Atributos* dolar, Atributos* um, Atributos* dois, Atributos* tres, string operador);
void cast(Atributos* dolar, Atributos* um, Atributos* tres, string operador);
void processaToken(Atributos* dolar, Atributos* um, string tipo);
bool pertenceAoAtualEscopo(string label);
void fechaEscopo();
void abreEscopo();
STRINGMAP* buscarTkId(string label);
void declaracoes();

string opAritmetico[6][6];

string declaracoesDeVariaveis;

list<STRINGMAP*> pilhaDeMapas;

%}

%token TK_INT TK_FLOAT TK_BOOLEAN TK_CHAR TK_STRING
%token TK_MAIN TK_ID TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_BOOLEAN TK_TIPO_CHAR TK_TIPO_STRING
%token TK_MENOR TK_MAIOR TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL TK_DIFERENTE TK_OU TK_E
%token TK_WHILE TK_IF TK_ELSE TK_FOR TK_DO
%token TK_INC TK_DEC
%token TK_FIM TK_ERROR

%start INICIO

%right '='
%left '+' '-'
%left '*' '/' '%'
%left TK_INC TK_DEC
%left TK_OU
%left TK_E
%left TK_IGUAL TK_DIFERENTE
%left TK_MENOR TK_MAIOR TK_MENOR_IGUAL TK_MAIOR_IGUAL
%left '(' ')'

%%

INICIO		: S
			{

				cout << "\n\n/*Compilador FOCA*/\n#include<string.h>\n#include<stdio.h>\n\n" << endl;

				cout << declaracoesDeVariaveis << endl;

				cout << $$.traducao << endl;
			}
			;

S			: ESC_GLOBAL DECLARACOES ';' P
			{
				declaracoes();
				$$.traducao = $2.traducao + "\n" + $4.traducao;
			}
			| ESC_GLOBAL P
			{
				declaracoes();
				$$.traducao = $2.traducao;
			}
			;

P 			: TK_TIPO_INT TK_MAIN '(' ')' BLOCO
			{
				$$.traducao =  "int main(void)\n{\n" + $5.traducao + "\treturn 0;\n}\n\n";
			}
			;

ESC_GLOBAL		: 
				{
					abreEscopo();	
				}
				;
/*DECL_GLOBAL	: 
			{
				declaracoes();	
			}
			;*/

INICIO_ESC	: '{'
			{
				abreEscopo();
				//cout << "\nAbertura: "<< pilhaDeMapas.size() << endl;
				$$.traducao = "";
			}

FIM_ESC		: '}'
			{
				declaracoes();
				fechaEscopo();
				//cout << "\nFechamento: " << pilhaDeMapas.size() << endl;
				$$.traducao = "";
			}

BLOCO		: INICIO_ESC COMANDOS FIM_ESC
			{
				$$.traducao = $2.traducao;
			}
			;

DECLARACOES : DECLARACOES ';' DECLARACAO
			{
				$$.traducao = $1.traducao + $3.traducao;
			}
			| DECLARACAO
			{
				$$.traducao = $1.traducao;
			}
			|
			;

DEC_FUNCAO : DECLARACAO ',' DEC_FUNCAO
			{
				$$.traducao = $1.traducao + ", " + $3.traducao;
			}
			| DECLARACAO
			{
				$$.traducao = $1.traducao;
			}
			;

COMANDOS	: COMANDO COMANDOS
			{
				$$.traducao = $1.traducao + "\n" + $2.traducao;
			}
			|
			{
				$$.traducao = "";
			}
			;

COMANDO 	: E ';'
			| DECLARACAO ';'
			| ATRIBUICAO ';'
			| IF
			| WHILE
			| FOR
			| DO
			| FUNCAO
			;

ATRIBUICAO	: TK_ID '=' E
			{
				STRINGMAP* mapa = buscarTkId($1.label);

				if(mapa == NULL)
					yyerror("Variavel nao declarada");

				$$.label = (*mapa)[$1.label].label;
				$$.tipo = (*mapa)[$1.label].tipo;

				//cout << "\n um " << $1.label << "\n" << endl;
				$1.label = $$.label;

				//atribuicao (&$$, &$1, &$3);

				if ($$.tipo == $3.tipo)
				{
					if($$.tipo == "string")
					{
						//cout << "\n dolar " << $$.label << "\n" << endl;
						//cout << "\n" << $3.tamanho << "\n" << endl;
						(*mapa)[$1.label].tamanho = $3.tamanho;
						(*mapa)[$1.label].label = $1.label + "["+ intToString($3.tamanho) +"]";
						(*mapa)[$1.label].tipo = std::string("char");
						$$.traducao = $3.traducao + "\t" + "strcpy(" + $1.label + ", " + $3.label + ");\n";
					}
					else
					{
						$$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
					}
				}
				else
				{
					if (opAritmetico[tipoToIndice($$.tipo)][tipoToIndice($3.tipo)] == "ilegal") 
					{
						yyerror("Erro!! Atribuição ilegal!");
					}
					else
					{
						//tratar no mapa
						$$.traducao = $3.traducao + "\t" + $1.label + " = (" + $$.tipo + ") " + $3.label + ";\n";
					}
				}
			}
			| TK_ID TK_INC // E ++
			{
				traducaoOpAritmeticaIncDec(&$$, &$1, "++");
			}
			| TK_ID TK_DEC // E --
			{
				traducaoOpAritmeticaIncDec(&$$, &$1, "--");
			}
			| TK_INC TK_ID // ++ E
			{
				traducaoOpAritmeticaIncDec(&$$, &$2, "++");
			}
			| TK_DEC TK_ID// -- E
			{
				traducaoOpAritmeticaIncDec(&$$, &$2, "--");
			}
			;

TIPO		:	TK_TIPO_INT
			{
				$$.label = "int";
				$$.tipo = "int";
			}
			|	TK_TIPO_FLOAT
			{
				$$.label = "float";
				$$.tipo = "float";
			}
			|	TK_TIPO_BOOLEAN
			{
				$$.label = "boolean";
				$$.tipo = "boolean";
			}
			|	TK_TIPO_STRING
			{
				$$.label = "string";
				$$.tipo = "string";
			}
			|	TK_TIPO_CHAR
			{
				$$.label = "char";
				$$.tipo = "char";
			}
			; 

DECLARACAO	: TIPO TK_ID
			{

				STRINGMAP* mapa = pilhaDeMapas.front();

				if(!pertenceAoAtualEscopo($2.label))
				{
					(*mapa)[$2.label].label = generateLabel();
					(*mapa)[$2.label].tipo = $1.tipo;
				}

				$$.tipo = (*mapa)[$2.label].tipo;

				$2.label = (*mapa)[$2.label].label;

				if ($$.tipo == "string")
				{
					(*mapa)[$2.label].tipo = std::string("char");
					(*mapa)[$2.label].label = $2.label + "[1000]";
					(*mapa)[$2.label].tamanho = 1000;
					$$.traducao = "";
				}
				else 
				{
					$$.traducao = "";
				}
			
			}	
			| DECLARACAO ',' TK_ID
			{
				STRINGMAP* mapa = pilhaDeMapas.front();

				if(!pertenceAoAtualEscopo($3.label))
				{
					(*mapa)[$3.label].label = generateLabel();
					(*mapa)[$3.label].tipo = $1.tipo;
				}

				$$.tipo = (*mapa)[$3.label].tipo;
				$3.label = (*mapa)[$3.label].label;

				if ($$.tipo == "string")
				{
					(*mapa)[$3.label].tipo = std::string("char");
					(*mapa)[$3.label].label = $3.label + "[1000]";
					(*mapa)[$3.label].tamanho = 1000;
					$$.traducao = "";
				}
				else 
				{
					$$.traducao = "";
				}
			}	
			| DECLARACAO ',' TK_ID '=' E
			{
				STRINGMAP* mapa = pilhaDeMapas.front();

				if(!pertenceAoAtualEscopo($3.label))
				{
					(*mapa)[$3.label].label = generateLabel();
					(*mapa)[$3.label].tipo = $1.tipo;
				}

				$$.tipo = (*mapa)[$3.label].tipo;
				$3.label = (*mapa)[$3.label].label;

				//atribuicao (&$$, &$3, &$5);

				if ($$.tipo == $5.tipo)
				{
					if($$.tipo == "string")
					{
						(*mapa)[$3.label].tamanho = $5.tamanho;
						(*mapa)[$3.label].label = $3.label + "["+ intToString($5.tamanho) +"]";
						(*mapa)[$3.label].tipo = std::string("char");
						$$.traducao = $5.traducao + "\t" + "strcpy(" + $3.label + ", " + $5.label + ");\n";
					}
					else
					{
						$$.traducao = $5.traducao + "\t" + $3.label + " = " + $5.label + ";\n";
					}
				}
				else
				{
					if (opAritmetico[tipoToIndice($$.tipo)][tipoToIndice($5.tipo)] == "ilegal") 
					{
						yyerror("Erro!! Atribuição ilegal!");
					}
					else
					{
						//tratar no mapa
						$$.traducao = $5.traducao + "\t" + $3.label + " = (" + $$.tipo + ") " + $5.label + ";\n";
					}
				}
			}
			| TIPO TK_ID '=' E
			{
				STRINGMAP* mapa = pilhaDeMapas.front();

				if(!pertenceAoAtualEscopo($2.label))
				{
					(*mapa)[$2.label].label = generateLabel();
					(*mapa)[$2.label].tipo = $1.tipo;
				}
				
				$$.tipo = (*mapa)[$2.label].tipo;
				$2.label = (*mapa)[$2.label].label;

				if ($$.tipo == $4.tipo)
				{
					if($$.tipo == "string")
					{

						//cout << "\n" << $4.tamanho << "\n" << endl;
						(*mapa)[$2.label].tamanho = $4.tamanho;
						(*mapa)[$2.label].label = $2.label + "["+ intToString($4.tamanho) +"]";
						(*mapa)[$2.label].tipo = std::string("char");
						$$.traducao = $4.traducao + "\tstrcpy(" + $2.label + ", " + $4.label + ");\n";
					}
					else
					{
						$$.traducao = $4.traducao + "\t" + $2.label + " = " + $4.label + ";\n";
					}
				}
				else
				{
					if (opAritmetico[tipoToIndice($$.tipo)][tipoToIndice($4.tipo)] == "ilegal") 
					{
						yyerror("Erro!! Atribuição ilegal!");
					}
					else
					{
						//tratar no mapa
						$$.traducao = $4.traducao + "\t" + $2.label + " = (" + $$.tipo + ") " + $4.label + ";\n";
					}
				}
			}				
			;

IF 			: TK_IF '(' E ')' BLOCO
			{
				//string blocoIf = geraBloco();
				string blocoEnd = geraBloco();
			    $$.traducao = $3.traducao + "\n\tif (!" + $3.label +") goto " + blocoEnd + ";\n\n" + $5.traducao + "\t" + blocoEnd + ":\n";
			}
			| TK_IF '(' E ')' BLOCO TK_ELSE BLOCO
			{
				string blocoIf = geraBloco();
			    string blocoElse = geraBloco();
			    string blocoEnd = geraBloco();
			    $$.traducao = $3.traducao + "\n\tif (!" + $3.label +") goto " + blocoElse + ";\n\n" + $5.traducao  + "\tgoto " + blocoEnd  + ";\n\n\t" + blocoElse + ":\n"+$7.traducao + "\t" + blocoEnd + ":\n";
			}
			;

WHILE		: TK_WHILE '(' E ')' BLOCO
		    {
			    string blocoIf = geraBloco();
			    string blocoElse = geraBloco();
			    $$.traducao = $3.traducao + "\n\t" + blocoIf + ":" + "\n\tif (!" + $3.label +") goto " + blocoElse + ";\n\n" + $5.traducao + "\tgoto " + blocoIf + ";\n\n\t" + blocoElse + ":\n";
			}
	    	;

DO 			: TK_DO BLOCO TK_WHILE '(' E ')' ';'
			{
				string blocoIf = geraBloco();
			    string blocoElse = geraBloco();
			    $$.traducao = $5.traducao + "\n\t" + blocoIf + ":\n" + $2.traducao + "\tif (!" + $5.label + ") goto " + blocoElse + ";\n\tgoto " + blocoIf + ";\n\n\t" + blocoElse + ":\n";
			}
			;

FOR 		: TK_FOR '(' ATRIBUICAO ';' E ';' ATRIBUICAO ')' BLOCO
			{
				string blocoIf = geraBloco();
			    string blocoElse = geraBloco();
			    $$.traducao = $3.traducao + $5.traducao + "\n\t" + blocoIf + ":\n\tif (!" + $5.label +") goto " + blocoElse + ";\n\n" + $9.traducao + $7.traducao + "\tgoto " + blocoIf + ";\n\n\t" + blocoElse + ":\n";
			
			}
			;

FUNCAO		: TIPO TK_ID '(' DEC_FUNCAO ')' BLOCO 
			{
				$$.traducao = "\t" + $1.label + " " + $2.label + "(" + $4.traducao + ") {\n\t" + $6.traducao + "\t}";
			}
			;

E 			: E '+' E
			{
				traducaoOpAritmetica(&$$, &$1, &$3, '+');
			}
			| E '-' E
			{
				traducaoOpAritmetica(&$$, &$1, &$3, '-');
			}			
			| E '*' E
			{
				traducaoOpAritmetica(&$$, &$1, &$3, '*');
			}			
			| E '/' E
			{
				traducaoOpAritmetica(&$$, &$1, &$3, '/');
			}		
			| E '%' E
			{
				traducaoOpAritmetica(&$$, &$1, &$3, '%');
			}	
			| '(' E ')'
			{
				//tratar no mapa
				$$.label = generateLabel();
				$$.tipo = $2.tipo;
				$$.traducao = $2.traducao + "\t" + $$.tipo + " " + $$.label + " = " + $2.label + ";\n";
			}
			| E TK_MENOR_IGUAL E
			{
				logica(&$$, &$1, &$2, &$3, "<=");
			}
			| E TK_MAIOR_IGUAL E
			{
				logica(&$$, &$1, &$2, &$3, ">=");
			}
			| E TK_OU E
			{
				logica(&$$, &$1, &$2, &$3, "||");
			}
			| E TK_E E
			{
				logica(&$$, &$1, &$2, &$3, "&&");
			}
			| E TK_IGUAL E
			{
				logica(&$$, &$1, &$2, &$3, "==");
			}
			| E TK_DIFERENTE E
			{
				logica(&$$, &$1, &$2, &$3, "!=");
			}
			| E TK_MENOR E
			{
				logica(&$$, &$1, &$2, &$3, "<");
			}
			| E TK_MAIOR E
			{
				logica(&$$, &$1, &$2, &$3, ">");
			}
			| TK_INT
			{
				processaToken(&$$, &$1, "int");
			}
			| TK_FLOAT
			{
				processaToken(&$$, &$1, "float");
			}
			| TK_BOOLEAN
			{
				processaToken(&$$, &$1, "boolean");
			}
			| TK_STRING
			{
				processaToken(&$$, &$1, "string");
			}
			| TK_CHAR
			{
				processaToken(&$$, &$1, "char");
			}
			| TK_ID
			{
				//STRINGMAP* mapa = pilhaDeMapas.front();

				STRINGMAP* mapa = buscarTkId($1.label);

				$$.label = (*mapa)[$1.label].label;
				$$.tipo = (*mapa)[$1.label].tipo;
				$$.tamanho = (*mapa)[$1.label].tamanho;
				$$.traducao = "";
			}
			;
%%

#include "lex.yy.c"

int yyparse();

int main( int argc, char* argv[] )
{
	opAritmetico[1][1] = "int";
	opAritmetico[1][2] = "float";
	opAritmetico[1][3] = "ilegal";
	opAritmetico[1][4] = "string";
	opAritmetico[1][5] = "ilegal";
	opAritmetico[2][1] = "float";
	opAritmetico[2][2] = "float";
	opAritmetico[2][3] = "ilegal";
	opAritmetico[2][4] = "string";
	opAritmetico[2][5] = "ilegal";
	opAritmetico[3][1] = "ilegal";
	opAritmetico[3][2] = "ilegal";
	opAritmetico[3][3] = "string";
	opAritmetico[3][4] = "string";
	opAritmetico[3][5] = "ilegal";
	opAritmetico[4][1] = "string";
	opAritmetico[4][2] = "string";
	opAritmetico[4][3] = "string";
	opAritmetico[4][4] = "string";
	opAritmetico[4][5] = "ilegal";
	opAritmetico[5][1] = "ilegal";
	opAritmetico[5][2] = "ilegal";
	opAritmetico[5][3] = "ilegal";
	opAritmetico[5][4] = "ilegal";
	opAritmetico[5][5] = "ilegal";

	yyparse();

	return 0;
}

int tipoToIndice(string tipo)
{
	if(tipo == "int") 
		return 1;
	else if(tipo == "float") 
		return 2;
	else if(tipo == "string") 
		return 3;
	else if(tipo == "char") 
		return 4;
	else if(tipo == "boolean") 
		return 5;
}

void traducaoOpAritmeticaIncDec(Atributos* dolar, Atributos* um, string operador)
{

	//STRINGMAP* mapa = pilhaDeMapas.front();

	//string label = generateLabel();
	//string tipo = opAritmetico[tipoToIndice(um->tipo)][tipoToIndice(tres->tipo)];

	//cout << um->traducao << " ###########" << endl;

	STRINGMAP* mapa = buscarTkId(um->label);

	if(mapa == NULL)
		yyerror("Variavel nao declarada");

	um->label = (*mapa)[um->label].label;
	um->traducao = "";
	
	dolar->traducao = um->traducao + "\t";

	if(um->tipo == "string" || um->tipo == "char")
	{
		yyerror("Erro!! Atribuição ilegal!");
	}
	else
	{
		if (operador == "++") {
			dolar->traducao += um->label + " = " + um->label + " + 1;\n";
		}
		else if (operador == "--") {
			dolar->traducao += um->label + " = " + um->label + " - 1;\n";
		}
		
	}
}

void traducaoOpAritmetica(Atributos* dolar, Atributos* um, Atributos* tres, char operador)
{
	STRINGMAP* mapa = pilhaDeMapas.front();

	string label = generateLabel();
	string tipo = opAritmetico[tipoToIndice(um->tipo)][tipoToIndice(tres->tipo)];

	(*mapa)[label].label = label;
	(*mapa)[label].traducao = "";
	(*mapa)[label].tipo = tipo;
	dolar->tipo = tipo;
	dolar->label = label;

	dolar->traducao = um->traducao + tres->traducao + "\t";

	if (um->tipo != tres->tipo)
	{
		if (dolar->tipo == "ilegal") 
		{
			yyerror("Erro!! Atribuição ilegal!");
		}
		else if (dolar->tipo == um->tipo)
		{
			dolar->traducao += dolar->label + " = " + um->label + " " + operador +" (" + dolar->tipo + ") " + tres->label + ";\n";
		}
		else if (dolar->tipo == tres->tipo)
		{	
			dolar->traducao += dolar->label + " = (" + dolar->tipo + ") " + um->label + " " + operador + " " + tres->label + ";\n";
		}
	}
	else
	{

		if(dolar->tipo == "string" && operador == '+')
		{
			dolar->tamanho = (*mapa)[um->label].tamanho + (*mapa)[tres->label].tamanho;
			dolar->traducao = um->traducao + tres->traducao + "\tstrcpy(" + dolar->label + ", " + um->label + ");\n\t" + "strcat(" + dolar->label + ", " + tres->label +");\n";
			(*mapa)[label].label = dolar->label +"[" + intToString(dolar->tamanho) + "]";
			(*mapa)[label].traducao = "";
			(*mapa)[label].tamanho = dolar->tamanho;
			(*mapa)[label].tipo = std::string("char");
		}
		else
		{
			dolar->traducao += dolar->label + " = " + um->label + " " + operador + " " + tres->label + ";\n";
		}
		
	}
}

void cast(Atributos* dolar, Atributos* um, Atributos* tres, string operador)
{
	
	if (dolar->tipo == "ilegal") 
	{
		yyerror("Erro!! Atribuição ilegal!");
	}
	else if (dolar->tipo == um->tipo)
	{
		dolar->traducao += dolar->label + " = " + um->label + " " + operador +" (" + dolar->tipo + ") " + tres->label + ";\n";
	}
	else if (dolar->tipo == tres->tipo)
	{	
		dolar->traducao += dolar->label + " = (" + dolar->tipo + ") " + um->label + " " + operador + " " + tres->label + ";\n";
	}
	
}


string geraBloco()
{

	static int bloco = 0;

	stringstream label;

	label << "bloco" << bloco++;
	
	return label.str();
}

string intToString(int label)
{
	stringstream out;
	out << label;
	return out.str();
}

void yyerror( string MSG )
{
	cout << MSG << endl;
	exit (0);
}

void processaToken(Atributos* dolar, Atributos* um, string tipo)
{
	STRINGMAP* mapa = pilhaDeMapas.front();

	string label = generateLabel();
	dolar->tipo = tipo;
	dolar->label = label;

	if (tipo != "string")
	{
		(*mapa)[label].label = label;
		(*mapa)[label].traducao = um->traducao;
		(*mapa)[label].tipo = tipo;
		dolar->traducao = "\t" + dolar->label + " = " + um->traducao + ";\n";
		//dolar->declaracao = dolar->tipo + " " + dolar->label + ";\n";
	}
	else
	{
		string as = std::string("\'");

		if (um->traducao.find(as) != std::string::npos) {
    		um->traducao = um->traducao.replace(um->traducao.begin(),um->traducao.begin()+1,"\"");
    		um->traducao = um->traducao.replace(um->traducao.end()-1,um->traducao.end(),"\""); 
		}

		dolar->tamanho = um->traducao.length()-2;
		//cocout << "\n" << dolar->tamanho << "\n" << endl;
		dolar->traducao = "\tstrcpy(" + dolar->label + ", " + um->traducao + ");\n";
		(*mapa)[label].label = dolar->label + "[" + intToString(dolar->tamanho) + "]";
		(*mapa)[label].tipo = std::string("char");
		(*mapa)[label].tamanho = dolar->tamanho;
		//dolar->declaracao = "char " + dolar->label + "[" + intToString(dolar->tamanho) + "]" + ";\n";
	}
}

void atribuicao (Atributos* dolar, Atributos* um, Atributos* tres)
{
	STRINGMAP* mapa = buscarTkId(um->label);

	if (dolar->tipo == tres->tipo)
	{
		if(dolar->tipo == "string")
		{
			(*mapa)[um->label].label = dolar->label + "["+ intToString(tres->tamanho) +"]";
			(*mapa)[um->label].tipo = std::string("char");
			dolar->traducao = tres->traducao + "\tstrcpy(" + dolar->label + ", " + tres->label + ");\n";
		}
		else
		{
			dolar->traducao = tres->traducao + "\t" + um->label + " = " + tres->label + ";\n";
		}
	}
	else
	{
		if (opAritmetico[tipoToIndice(dolar->tipo)][tipoToIndice(tres->tipo)] == "ilegal") 
		{
			yyerror("Erro!! Atribuição ilegal!");
		}
		else
		{
			dolar->traducao = tres->traducao + "\t" + dolar->label + " = (" + dolar->tipo + ") " + tres->label + ";\n";
		}
	}
}

void logica(Atributos* dolar, Atributos* um, Atributos* dois, Atributos* tres, string operador)
{
	STRINGMAP* mapa = pilhaDeMapas.front();

	string label = generateLabel();
    dolar->label = label;
    dolar->tipo = opAritmetico[tipoToIndice(um->tipo)][tipoToIndice(tres->tipo)];
    string logica = dois->traducao;

    dolar->traducao = um->traducao + tres->traducao + "\t";

    if (um->tipo != tres->tipo)
	{
		cast(dolar, um, tres, logica);
	}
	else
	{
		dolar->traducao += dolar->label + " = " + um->label + " " + operador + " " + tres->label + ";\n";
	}
    (*mapa)[label].label = label;
	(*mapa)[label].traducao = "";
	(*mapa)[label].tipo = dolar->tipo;
}

string generateLabel()
{
	static int counter = 0;
	stringstream label;

	label << "temp" << counter++;
	
	return label.str();
	
}

void declaracoes()
{
	STRINGMAP mapa = *pilhaDeMapas.front();
	STRINGMAP::iterator i;
	stringstream ss;
	
	for(i = mapa.begin(); i != mapa.end(); i++){	
		if(i->second.tipo != "string")
			ss << i->second.tipo << " " << i->second.label << ";\n";
	}
	declaracoesDeVariaveis+= ss.str() + "\n";
}

void abreEscopo()
{
	STRINGMAP* mapa = new STRINGMAP();
	pilhaDeMapas.push_front(mapa);
}

void fechaEscopo()
{
	pilhaDeMapas.pop_front();
}

bool pertenceAoAtualEscopo(string label)
{
	STRINGMAP* mapa = pilhaDeMapas.front();

	if(	mapa->find(label) == mapa->end())
		return false;
	else
		return true;	
}

STRINGMAP* buscarTkId(string label)
{
	list<STRINGMAP*>::iterator i;
	
	for(i = pilhaDeMapas.begin(); i != pilhaDeMapas.end(); i++)
	{
		STRINGMAP* mapa = *i;

		if(mapa->find(label) != mapa->end())
		{
			return 	mapa;
		}
	}

	return NULL;
}

