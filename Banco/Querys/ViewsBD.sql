use dbOrgan;
/*SELECT LAST_INSERT_ID();*/
-- =================================================================== [NOME] ==================================================== 
-- =============================================================================================================================== 
 
-- =================================================================== PESSOA ====================================================
	drop view if exists vwEndereco;
	create view vwEndereco as(
	select E.CEP,  R.Logradouro `Rua`, concat(B.Bairro,' - ', C.Cidade,'/', Es.UF) `BCE` 
	 from tbEndereco E 
		inner join tbLogradouro R on E.IdRua = R.Id
		inner join tbBairro B on R.IdBairro = B.Id
		inner join tbCidade C on B.IdCidade = C.Id
		inner join tbEstado Es on C.IdEstado = Es.Id
	);

	drop view if exists vwTelefone;
	create view vwTelefone as(
	select T.Id, concat('(',T.IdDDD,') ',T.Numero,' - ',Ti.Tipo) `Telefone`
	 from tbTelefone T
		inner join tbTipoTel Ti on Ti.Id = T.IdTipo
	); 

	drop view if exists vwPessoa;
	create view vwPessoa as(
	select P.Id, P.Nome, P.Email, concat(E.Rua,', ', P.NumeroEndereco,' - ', ifnull(P.CompEndereco, 'Sem Complemento'),' - ',E.BCE,' - ',E.CEP) `Endereço`,  group_concat(T.Telefone separator '; ') `Telefones`
	 from tbPessoa P 
		inner join vwEndereco E on P.CEP = E.CEP
		inner join tbTelefonePessoa TP on P.Id = TP.IdPessoa
		inner join vwTelefone T on T.Id = TP.IdTelefone
	 group by P.Id
	 );
	 
	 drop view if exists vwPessoaFisica;
	 create view vwPessoaFisica as(
	 select P.Id, P.Nome, F.CPF, F.RG, date_format(F.DataNasc, '%d/%m/%Y') `Data de Nascimento`, P.Telefones, P.Email, P.`Endereço`
	  from tbPessoaFisica F 
		inner join vwPessoa P on F.IdPessoa = P.Id
	);

	drop view if exists vwPessoaJuridica;
	create view vwPessoaJuridica as(
	select P.Id, P.Nome, J.RazaoSocial, J.CNPJ, J.IE, P.Telefones, P.Email, P.`Endereço`
	 from tbPessoaJuridica J 
		inner join vwPessoa P on J.IdPessoa = P.Id
	);
	 
	drop view if exists vwFuncionario;
	create view vwFuncionario as(
	select F.Id, PF.Nome,  C.Nome `Cargo`, F.Salario `Salário`, PF.CPF, PF.RG, PF.`Data de Nascimento`, PF.Telefones, PF.Email, PF.`Endereço`
	 from tbFuncionario F
		inner join vwPessoaFisica PF on F.IdPessoa = PF.Id
		inner join tbCargo C on F.IdCargo = C.Id
	 where F.`Status` = true
	); 

	drop view if exists vwFornecedor;
	create view vwFornecedor as(
	select F.Id, PJ.Nome `Nome Fantasia`, PJ.RazaoSocial `Razão Social`, PJ.CNPJ, PJ.IE, PJ.Telefones, PJ.Email, PJ.`Endereço`
	 from tbFornecedor F
		inner join vwPessoaJuridica PJ on PJ.Id = F.IdPessoa
		where F.`Status` = true
	);  
-- ===============================================================================================================================  

-- =================================================================== ESTOQUE ============================================  
    drop view if exists vwItems;
    create view vwItems as
	(SELECT S.IdEstoque `Id`,
			S.Nome `Item`,
            E.Qtd `Quantidade`,
            E.UM `Unidade de Medida`,
            E.ValorUnit `Valor Unitário (R$)`,
		   (E.Qtd * E.ValorUnit) `Valor Total (p/Produto)`,
           'Semente' `Categoria`
	FROM tbEstoque E
	INNER JOIN tbSemente S ON E.Id = S.IdEstoque)
	UNION
	(SELECT I.IdEstoque, 
			I.Nome,
            E.Qtd,
            E.UM,
            E.ValorUnit,
            (E.Qtd * E.ValorUnit),
            C.Categoria
	FROM tbEstoque E
	INNER JOIN tbInsumo I ON E.Id = I.IdEstoque
	INNER JOIN tbCategoria C ON C.Id = I.IdCategoria)
	UNION
	(SELECT M.IdEstoque,
			M.Nome,
            E.Qtd,
            E.UM,
            E.ValorUnit,
            (E.Qtd * E.ValorUnit),
            M.Tipo
	FROM tbMaquina M
	INNER JOIN tbEstoque E ON M.IdEstoque = E.Id)
    UNION
	(SELECT P.IdEstoque,
			P.Nome,
            E.Qtd,
            E.UM,
            E.ValorUnit,
            (E.Qtd * E.ValorUnit),
            'Produto'
	FROM tbProduto P
	INNER JOIN tbEstoque E ON P.IdEstoque = E.Id)
    order by `Categoria`;
-- ===============================================================================================================================  

-- =================================================================== FLUXO DE CAIXA ============================================
	DELIMITER $$ -- Consertar
    drop function if exists spValorTotal$$
    create function spValorTotal(QtdProd double, ValorUnitario double, Desconto decimal(5,2))
    returns double 
    deterministic
    begin
			
			declare VDS, ValorTotal /*Valor Sem Desconto*/ double;
			set VDS = ((@QtdProd * @ValorUnitario));
			set ValorTotal = VDS - (VDS * @Desconto);
            return ValorTotal;
	end$$
    DELIMITER ;
  
	drop view if exists vwCompra;
    create view vwCompra as(
    select C.Id `Compra`, DATE_FORMAT(C.`Data`, '%d/%m/%Y') `Data`,
		   group_concat(distinct concat(I.Item, ' - ', IC.QtdProd) separator ', ') `Itens - Quantidade Comprada`,
		   SUM(spValorTotal(IC.QtdProd, E.ValorUnit, C.Desconto)) `Valor Total`
		from tbItensComprados IC INNER JOIN tbEstoque E on IC.IdEstoque = E.Id
								 INNER JOIN tbCompra C on IC.IdCompra = C.Id
                                 INNER JOIN vwItems I on I.Id = E.Id
	group by `Compra`
    );
    
     select * from vwCompra;

    drop view if exists vwSaida;
	create View vwSaida as select DATE_FORMAT(Co.`Data`, '%d/%m/%Y') `Data`, (SUM(M.ValorPago) + SUM(D.ValorPago)  + SUM(Co.`Valor Total`)) `Saída` from tbManutencao M, tbDespesa D, vwCompra Co group by Co.`Data`;

	drop view if exists vwVenda;
	create view vwVenda as(
    select V.Id `Venda`, (DATE_FORMAT(V.`Data`, '%d/%m/%Y')) `Data`, E.Id 'IdEstoque',
    SUM(((IV.QtdVendida * E.ValorUnit))
    - (IV.QtdVendida * E.ValorUnit) * IV.DescontoProd) ValorTotal
		from tbItensVendidos IV INNER JOIN tbEstoque E on IV.IdEstoque = E.Id
								INNER JOIN tbVenda V on IV.IdVenda = V.Id
	group by `Venda`
    );
    
    drop view if exists vwSaldo;
    create view vwSaldo as select (IFNULL(V.ValorTotal, 0) - IFNULL(S.Saída, 0))  `Saldo` from vwSaida S, vwVenda V;
	
    drop view if exists vwFluxoDeCaixa; 
    create view vwFluxoDeCaixa as
    select IFNULL(S.`Saída`,0) `Saída`, IFNULL(V.ValorTotal, 0) `Entrada`, Sal.Saldo, monthname(S.`Data`) `MÊS`, year(S.`Data`) `ANO`
    from vwVenda V, vwSaida S, vwSaldo Sal
    where S.`Data` = V.`Data`
    group by `ANO`; 
    
    -- ================================================================= function FLUXO DE CAIXA ============================================  
	DELIMITER $$
    drop function if exists spFluxoCaixa$$ 
	create function spFluxoCaixa()
	returns @FluxoCaixa table(
					@Compra double,
					@Venda double,
					@Saldo double,
					@MES varchar(15),
					@ANO int)
	begin	
		declare double Venda, Compra, TVenda, TCompra, Saldo;
        declare date  DtC, dtV;
        DECLARE done INT DEFAULT 0;
        DECLARE curCompra CURSOR FOR SELECT `Valor Total` FROM vwCompra group by `Data`;
        declare curDtC cursor for select `Data` from vwCompra;
        DECLARE curVenda CURSOR FOR SELECT ValorTotal FROM vwVenda;
        declare curDtV cursor for select `Data` from vwVenda;
        
		  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

		  OPEN curCompra;
          open curDtC;
          open curVenda;
          open curDtV;

		  REPEAT
			FETCH curCompra INTO Compra;
            fetch curDtC into DtC;
            
			SET TCompra +=  Compra;
              
		  UNTIL done END REPEAT;
		  CLOSE curCompra;
          close curDtC;
          
          REPEAT
            fetch curVenda into Venda;
            fetch curDtV into DtV;
            
			SET TVenda +=  Venda;
		  
          UNTIL done END REPEAT;
		  CLOSE curVenda;
          close curDtV;
          
		  
	end
	DELIMITER ;
-- MUDAR VALOR DOS NOMES DAS DATAS PRA PORTUGUES    SET lc_time_names = 'pt_BR';
-- =============================================================================================================================== 

-- =================================================================== PROC ESTOQUE ===============================================
	DELIMITER $$
    
    drop procedure if exists spInsertEstoque$$
    create procedure spInsertEstoque(
    in
		Qnt double,
        UnM int,
        ValUnit double
    )
    begin
		if Qnt < 0 then
			signal sqlstate '45000'
			   set message_text = 'Valor menor que zero!';
		else
        
        insert into tbEstoque(Qtd, UM, ValorUnit) values(Qnt, UnM, ValUnit);
        end if;
    end$$
    
    drop procedure if exists spInsertSemente$$
    create procedure spInsertSemente(
	in 
		Qnt double,
        UnM int,
        ValUnit double,
        Nome varchar(50),
        Solo varchar(50),
        IncSol decimal(5,2),
        IncVento decimal(5,2),
        Acidez decimal(5,2)
    )
    begin
        declare conta1 int;
        declare conta2 int;
        declare idE int;
        set conta1 = (select count(*) from tbEstoque); 
        
		call spInsertEstoque(Qnt, UnM, ValUnit);

        set conta2 = (select count(*) from tbEstoque); 
        
        if (conta2 = conta1 + 1) then
			set idE = (select Id from tbEstoque order by Id desc limit 1 );
			insert into tbSemente(IdEstoque, Nome, Solo, IncSol, IncVento, Acidez) value(IdE, Nome, Solo, IncSol, IncVento, Acidez);
		end if;
    end$$

    drop procedure if exists spInsertMaquina$$
    create procedure spInsertMaquina(
	in 
		Qnt double,
        UnM int,
        ValUnit double,
        Nome varchar(50),
        Tipo int,
        Montadora varchar(75),
        `Desc` varchar(300),
        VidaUtil int,
        ValorInicial double,
        DeprMes double,
        DeprAno double
    )
    begin
        declare conta1 int;
        declare conta2 int;
        declare idE int;
        set conta1 = (select count(*) from tbEstoque); 
        
		call spInsertEstoque(Qnt, UnM, ValUnit);

        set conta2 = (select count(*) from tbEstoque); 
        
        if (conta2 = conta1 + 1) then
			set idE = (select Id from tbEstoque order by Id desc limit 1 );
			insert into tbMaquina(IdEstoque, Nome, Tipo, Montadora, `Desc`, VidaUtil, ValorInicial, DeprMes, DeprAno)
							value(IdE, Nome, Tipo, Montadora, `Desc`, VidaUtil, ValorInicial, DeprMes, DeprAno);
		end if;
    end$$

    drop procedure if exists spInsertInsumo$$
    create procedure spInsertInsumo(
	in 
		Qnt double,
        UnM int,
        ValUnit double,
        Nome varchar(50),
        `Desc` varchar(300),
        IdCategoria int
    )
    begin
        declare conta1, conta2, idE int;
        set conta1 = (select count(*) from tbEstoque); 
        
		call spInsertEstoque(Qnt, UnM, ValUnit);

        set conta2 = (select count(*) from tbEstoque); 
        
        if (conta2 = conta1 + 1) then
			set idE = (select Id from tbEstoque order by Id desc limit 1 );
			insert into tbInsumo(IdEstoque, Nome, `Desc`, IdCategoria) value(IdE, Nome, `Desc`, IdCategoria);
		end if;
    end$$

    drop procedure if exists spInsertProduto$$
    create procedure spInsertProduto(
	in 
		Qnt double,
        UnM int,
        ValUnit double,
        Nome varchar(50),
        `Desc` varchar(300)
    )
    begin
        declare conta1, conta2, idE int;
        
        set conta1 = (select count(*) from tbEstoque); 
        
		call spInsertEstoque(Qnt, UnM, ValUnit);

        set conta2 = (select count(*) from tbEstoque); 
        
        if (conta2 = conta1 + 1) then
			set idE = (select Id from tbEstoque order by Id desc limit 1 );
			insert into tbProduto(IdEstoque, Nome, `Desc`) value(IdE, Nome, `Desc`);
		end if;
    end$$
/*
    call spInsertSemente(2, 1, 1.50, 'Semente de Milho', null, null, null, null)$$
    call spInsertProduto(1, 1, 5.0, 'Milho', null)$$
    call spInsertInsumo(1, 3, 2.0, 'Pá', null, 2)$$
    call spInsertMaquina(1, 3, 2500, 'Tratorzinho', 1, 'Joana Motors', null, 2, 2300, 20, 240)$$*/
    DELIMITER ;
-- =============================================================================================================================== 
-- =================================================================== MANUTENÇÃO ================================================
drop view if exists vwQtdMa;
create view vwQtdMa as
select mm.IdMaquina, mm.IdManutencao, m.Nome, ifnull(count(IdMaquina), 0) `Quantidade de Manutenções`, ifnull(sum(ma.ValorPago), 0) `Custo Total`
	from tbMaquina m
    inner join tbMaquinaManutencao mm on m.IdEstoque = mm.IdMaquina
    inner join tbManutencao ma on ma.Id = mm.IdManutencao;

drop view if exists vwManutencao;
create view vwManutencao as
select mm.IdMaquina, mm.IdManutencao, M.Nome `Máquina`, M.Tipo `Tipo de Máquina`, Ma.Nome `Manutenção`, (DATE_FORMAT(MA.`Data`, '%d/%m/%Y')) `Data da Manutenção`, Ma.ValorPago `Valor da Manutenção`
 from tbMaquina M 
 inner join tbMaquinaManutencao mm 
	on mm.IdMaquina = M.IdEstoque
 inner join tbManutencao Ma 
	on Ma.Id = mm.IdManutencao;
-- =============================================================================================================================== 

-- =================================================================== PROC ESTOQUE ===============================================
	drop view if exists vwPragaOrDoenca ;
     create view vwPragaOrDoenca as
		select pd.Id, pd.Nome `Nome`,
        (case
			when pd.`P/D` = true then 'Praga'
            else'Doença'
		end) as `Tipo`,
		group_concat(a.Nome separator ', ') `Áreas`, c.`Status`
		from tbAreaPD apd
			inner join tbPragaOrDoenca pd on apd.IdPD = pd.Id
            inner join tbArea a on apd.IdArea = a.Id
            inner join tbControlePD cpd on cpd.IdPd = pd.Id
            inner join tbControle c on c.Id = cpd.IdControle
		group by `Id`;
	
    drop view if exists vwControle;
    create view vwControle as
    select c.Id, DATE_FORMAT(c.`Data`, '%d/%m/%Y') `Data`, c.`Status`, ifnull(c.`Desc`, 'Sem Descrição') `Descrição`, c.Efic `Eficiência(%)`,
		   c.NumLiberacoes `Número de Liberações`, group_concat(distinct p.Nome separator ', ' ) `Pragas/Doenças`,
           group_concat(distinct concat(i.Item, ' - ', ic.QtdUsada) separator ', ') `Itens Usados - Quantidade`
    from tbControle c
		inner join tbControlePD cpd on c.Id = cpd.IdControle
        inner join tbPragaOrDoenca p on cpd.IdPD = p.Id
        inner join tbItensControle ic on c.Id = ic.IdControle
        inner join vwItems i on ic.IdEstoque = i.Id
	group by c.Id;
    
-- =============================================================================================================================== 
SELECT * from VwCompra;
select * from vwVenda;