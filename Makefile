all: 	
		clear
		lex lexicav2.l
		yacc -d sintaticav1.8.3.y
		g++ -o glf y.tab.c -lfl

		./glf < exemplo.foca
