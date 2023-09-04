/*Modelo Relacional Simplificado: 
    
    funcionario(numerofuncionario(pk), nome, morada, codigoPostal, localidade, telefone, datanascimento, salario, username, password, codtipologin(fk)) 
    
    referenciapeca(referencia(pk), designacao, preco, duracaodias) 
    
    cliente(numerocliente(pk), nome, morada, codigopostal, localidade, nif) 
    
    documento(numerodoc(pk), cliente(fk), data, estadodocumento(fk)) 
    
    documentoaux(numerodoc(pk/fk), referenciapeca(pk/fk), quantidade) 
    
    ordemfabrico(numeroordem(pk), numerodoc(fk), 
    
    numerofuncionario(fk), datainicio, datafim) 
    
    estadodocumento(codigoestadodocumento(pk), descricao) 
    
    tipologin(cod(pk), descricao)*/

/*A. Qual/Quais os nomes dos funcionários que ganham abaixo de 1000 EUR ? Ordene por ordem ascendente (face ao salário)*/

SELECT funcionario.nome
FROM funcionario
WHERE funcionario.salario < 1000
ORDER BY funcionario.salario ASC;

/*B. Qual o nome do administrador (funcionário) do sistema?*/

SELECT funcionario.nome 
FROM funcionario, tipologin
WHERE funcionario.codtipologin=tipologin.cod
AND tipologin.descricao LIKE 'Administrador';

/*C. Para cada estado de documento (descrição), mostre quantos documentos tem associado?*/ 

SELECT estadodocumento.descricao, count(*) as totalDocAssociados
FROM estadodocumento, documento
WHERE estadodocumento.codigoestadodocumento=documento.estadodocumento
GROUP BY estadodocumento.descricao;

/*D. Quais os clientes (numerocliente) que possuem neste momento documentos que ainda estão ‘Em Análise’?*/ 

SELECT cliente.numerocliente
FROM cliente, documento, estadodocumento
WHERE cliente.numerocliente=documento.cliente
AND documento.estadodocumento=estadodocumento.codigoestadodocumento
AND estadodocumento.descricao LIKE 'Em análise';

/*E. Quais os clientes (nome) que não possuem qualquer ordem de fabrico associada?*/ 

SELECT cliente.nome
FROM cliente
WHERE cliente.numerocliente NOT IN(
	SELECT cliente.numerocliente
	FROM cliente, documento, ordemfabrico
	WHERE cliente.numerocliente=documento.cliente
	AND documento.numerodoc=ordemfabrico.numerodoc
);

/*F. Para cada cliente (nome), mostre quantas ordens de fabrico tem associadas? 
Inclua também os clientes que não possuem qualquer ordem de fabrico associada - Pode considerar o valor zero para esse efeito.*/ 

SELECT cliente.nome, count(*) as totalOF
FROM cliente, documento, ordemfabrico
WHERE cliente.numerocliente=documento.cliente
AND documento.numerodoc=ordemfabrico.numerodoc
GROUP BY cliente.nome
UNION
SELECT cliente.nome, 0
FROM cliente
WHERE cliente.numerocliente NOT IN(
	SELECT cliente.numerocliente
	FROM cliente, documento, ordemfabrico
	WHERE cliente.numerocliente=documento.cliente
	AND documento.numerodoc=ordemfabrico.numerodoc
	GROUP BY cliente.nome
);


/*G. Qual o cliente (nome) que mais ordens de fabrico possui?*/

SELECT cliente.nome, count(*) as totalOF
FROM cliente, documento, ordemfabrico
WHERE cliente.numerocliente=documento.cliente
AND documento.numerodoc=ordemfabrico.numerodoc
GROUP BY cliente.nome
HAVING totalOF=(
SELECT max(totalOF)
	FROM(
		SELECT cliente.nome, count(*) as totalOF
		FROM cliente, documento, ordemfabrico
		WHERE cliente.numerocliente=documento.cliente
		AND documento.numerodoc=ordemfabrico.numerodoc
		GROUP BY cliente.nome
	)as temp
);

/*H. Qual o cliente com maior ‘Valor a pagar’ com base no seguinte: 
Apenas serão contabilizadas as propostas aceites | Se o total a pagar 
for superior a 5000 EUR, o cliente tem 70% desconto associado. 
Senão, não existe qualquer desconto. | Mostre para além do nome do 
cliente o valor a pagar arredondado a 2 casas decimais*/

SELECT cliente.nome, ROUND(IF(sum(documentoaux.quantidade*referenciapeca.preco)>5000, sum((documentoaux.quantidade*referenciapeca.preco)*0.3), sum(documentoaux.quantidade*referenciapeca.preco)), 2) as valorAPagar
FROM cliente, documento, estadodocumento, documentoaux, referenciapeca
WHERE cliente.numerocliente=documento.cliente
AND documento.estadodocumento=estadodocumento.codigoestadodocumento
AND documento.numerodoc=documentoaux.numerodoc
AND documentoaux.referenciapeca=referenciapeca.referencia
AND estadodocumento.descricao LIKE 'Aceite'
GROUP BY cliente.nome
HAVING valorApagar=(
	SELECT max(valorAPagar)
	FROM(
		SELECT cliente.nome, ROUND(IF(sum(documentoaux.quantidade*referenciapeca.preco)>5000, sum((documentoaux.quantidade*referenciapeca.preco)*0.3), sum(documentoaux.quantidade*referenciapeca.preco)), 2) as valorAPagar
		FROM cliente, documento, estadodocumento, documentoaux, referenciapeca
		WHERE cliente.numerocliente=documento.cliente
		AND documento.estadodocumento=estadodocumento.codigoestadodocumento
		AND documento.numerodoc=documentoaux.numerodoc
		AND documentoaux.referenciapeca=referenciapeca.referencia
		AND estadodocumento.descricao LIKE 'Aceite'
		GROUP BY cliente.nome
	)as temp
);

/*A empresa detentora deste sistema de gestão, pretende automatizar vários 
processos e principalmente aumentar o tempo de produtividade. Assim, 
imediatamente após a mudança de estado de um documento de venda – 
orçamento – para ‘aceite’, a base de dados deve ter a capacidade para inserir 
automaticamente uma nova ordem de fabrico. Neste sentido, realize todos os 
passos necessários em SQL para garantir que este passo é feito pelo próprio 
servidor de base de dados e não pelo utilizador com as seguintes restrições: 
 - O funcionário responsável por todas as ordens de fabrico tem o código: 101 
 - Considera-se como data de início da ordem de fabrico como a data da 
aceitação (momento em que está a definir essa inserção) 
 - Todas as ordens de fabrico demoram 15 dias seguidos de produção. 
 - Todas as OFs que são via processo automático receberão uma codificação 
automática para o número da OF. Neste sentido, deverá ficar: 
OFxxxx/yyy 
Note-se que xxxx representa o ano atual (2021) e que yyy representa o número do 
documento aceite. É obrigatório representar o número com 3 dígitos 
independentemente do mesmo ter apenas uma dezena (por ex.) neste caso ficaria: 
OF2021/010 */

--Para quando sabemos qual é o id do estado em especifico
Delimiter $$
CREATE TRIGGER t1 AFTER UPDATE
ON documento FOR EACH ROW
BEGIN
	IF NEW.estadodocumento = 2 THEN
		INSERT INTO ordemfabrico VALUES(
			concat(
				'OF',
				extract(year FROM( now() ) ), 
				'/', 
				LPAD(OLD.numerodoc, 3, "000")
			), 
			OLD.numerodoc, 
			101, 
			date_format(date(now()), '%d/%m/%Y'), 
			date_format(date_add(date(now()), interval 15 day), '%d/%m/%Y')
		);
	END IF;
END $$
Delimiter ;

--Para quando temos n estados e não queremos ir a procura do id em especifico
Delimiter $$
CREATE TRIGGER t2 AFTER UPDATE
ON documento FOR EACH ROW
BEGIN
	Declare aceite int;
	SELECT codigoestadodocumento
	FROM estadodocumento
	WHERE estadodocumento.descricao LIKE 'Aceite'
	INTO aceite;
	IF NEW.estadodocumento=aceite THEN
		INSERT INTO ordemfabrico VALUES(
			concat(
				'OF',
				extract(year FROM( now() ) ), 
				'/', 
				LPAD(OLD.numerodoc, 3, "000")
			), 
			OLD.numerodoc, 
			101, 
			date_format(date(now()), '%d/%m/%Y'), 
			date_format(date_add(date(now()), interval 15 day), '%d/%m/%Y')
		);
	END IF;
END $$
Delimiter ;

DROP TRIGGER t2;
