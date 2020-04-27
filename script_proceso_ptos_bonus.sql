----**FINAL *********************************

--EXEC SP_CARGA_PUNTOS_BONUS 'WONG',20200411,20200413

--ALTER PROCEDURE SP_CARGA_PUNTOS_BONUS 
--@CADENA CHAR(5),
--@FECHAINI INT,
--@FECHAFIN INT

--AS

-- ====================================================
-- PROCESO:  PUNTOS BONUS
-- ====================================================

--=============================================================================================================
-- INPUT
-- Tiempo 1 min
-- ************************************************************************************************************

DECLARE @CADENA CHAR(5) = 'WONG'
DECLARE @FECHAINI INT = 20200401
DECLARE @FECHAFIN INT = 20200401

---- DECLARAMOS VARIABLES
DECLARE @COD_CADENA CHAR(2) = CASE WHEN @CADENA = 'WONG' THEN '01' ELSE '02' END
-- BACKUP DE DATA:
-- TEMPORAL.DBO.IVB_BONUS2020_V2_BCK

set nocount on


-- TEMPORAL DE FECHAS
--FECHAS
IF OBJECT_ID('TEMPDB..#FECHA') IS NOT NULL DROP TABLE #FECHA
SELECT IFECHA AS CODFECHA INTO #FECHA FROM [G200603SVHB8\IC_DATOS].CONFIG.DBO.IC_FECHASCOMPARATIVAS WHERE IFECHA>=@FECHAINI AND IFECHA<=@FECHAFIN
CREATE NONCLUSTERED INDEX IX_CODFECHA ON #FECHA(CODFECHA)

--TABLAS INPUTS
IF OBJECT_ID('TEMPORAL.DBO.IVB_BONUS2020_V2') IS NOT NULL DROP TABLE TEMPORAL.DBO.IVB_BONUS2020_V2

--TABLAS INTERMEDIAS
IF OBJECT_ID('TEMPORAL.DBO.IC_TICKET_HIST_CANJE') IS NOT NULL DROP TABLE TEMPORAL.DBO.IC_TICKET_HIST_CANJE
IF OBJECT_ID('TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD') IS NOT NULL DROP TABLE TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD

--TABLAS OUTPUTS
--IF OBJECT_ID('STAGE.[dbo].[TRX_TICKET_BONUS]')IS NOT NULL DELETE FROM STAGE.[dbo].[TRX_TICKET_BONUS]
--WHERE COD_DIA IN (SELECT * FROM #FECHA)

--IF OBJECT_ID('"g200603svhb5\ic_dw".[DW_CENCOFCIC].[dbo].[FACT_TICKET_BONUS]')IS NOT NULL DELETE FROM "g200603svhb5\ic_dw".[DW_CENCOFCIC].[dbo].[FACT_TICKET_BONUS]
--WHERE SK_DIA IN (SELECT * FROM #FECHA)


IF OBJECT_ID('TEMPDB..#CANJEADOS') IS NOT NULL DROP TABLE #CANJEADOS 
SELECT  CODFECHA
    ,CASE 
      WHEN CODTIENDALOST LIKE 'W%' THEN 'TH2'
      WHEN CODTIENDALOST ='I01' THEN 'I02'
      WHEN CODTIENDALOST IS NULL THEN '0'
      ELSE CODTIENDALOST 
    END AS CODTIENDALOST
    ,HORA
    ,CAJA
    ,TICKET
    ,CAJERA
    ,CODMATERIAL
    ,CODPROMOCION
    ,CODTICKET
    ,VTABS
    ,VTAQ
    ,DSCTO
    ,PTOSACUMTICKET
    ,PTOSCONSMATERIAL
    ,UNIDPROMOMATERIAL
INTO    #CANJEADOS        
FROM    [G200603SVHB8\IC_DATOS].ods.dbo.ticket WITH(NOLOCK)
WHERE   CODFECHA IN (SELECT * FROM #FECHA)
CREATE NONCLUSTERED INDEX IDX_CANJE1 ON #CANJEADOS (CODMATERIAL)
CREATE NONCLUSTERED INDEX IDX_CANJE2 ON #CANJEADOS (CODTIENDALOST)

---

IF OBJECT_ID('TEMPDB..#TIENDASW') IS NOT NULL DROP TABLE #TIENDASW
SELECT CODTIENDA,NOMBRETIENDA,CADENA,CODTIENDALOST, REGION
INTO #TIENDASW
FROM [G200603SVHB8\IC_DATOS].MAESTROS.DBO.VW_DETAILS_TIENDA
WHERE CADENA = @CADENA AND CODTIENDA NOT IN ('X082','HCHO','MRFL','PZNT','S004')
CREATE NONCLUSTERED INDEX IDX_TIENDA ON #TIENDASW (CODTIENDALOST)

IF OBJECT_ID('TEMPDB..#BONUS2') IS NOT NULL DROP TABLE #BONUS2
SELECT CODFECHA/100 PERIODO
,B.CADENA
,A.CODTIENDALOST
,A.CODFECHA
,B.CODTIENDA
,A.CAJA
,A.TICKET
,A.HORA
,(B.CODTIENDA+'-'+CAST(CODFECHA AS VARCHAR(8))+'-'+CAJA+'-'+TICKET+'-'+CAST(SUBSTRING(HORA,1,2) AS VARCHAR(2))
+CAST(SUBSTRING(HORA,4,2) AS VARCHAR(2)) ) AS CODTICKET2
,A.CODMATERIAL
,A.CODPROMOCION
,A.PTOSACUMTICKET
,A.PTOSCONSMATERIAL
,A.UNIDPROMOMATERIAL
INTO #BONUS2 FROM #CANJEADOS  A 
INNER JOIN #TIENDASW B ON A.CODTIENDALOST=B.CODTIENDALOST
CREATE NONCLUSTERED INDEX IDX_BONUS1 ON #BONUS2 (PERIODO)
CREATE NONCLUSTERED INDEX IDX_BONUS2 ON #BONUS2 (CODFECHA)


IF OBJECT_ID('TEMPDB..#CODPROMOCION_PB1') IS NOT NULL DROP TABLE #CODPROMOCION_PB1
SELECT DISTINCT PERIODO
            ,CADENA
            ,CODTIENDALOST
            ,CODFECHA
            ,CODTIENDA
            ,CODTICKET2
            ,CODMATERIAL
            ,CODTICKET2+CODMATERIAL LLAVE
INTO #CODPROMOCION_PB1
FROM #BONUS2  
WHERE CODPROMOCION=1
GROUP BY PERIODO,CADENA,CODTIENDALOST,CODFECHA,CODTIENDA,CODTICKET2,CODMATERIAL,CODTICKET2+CODMATERIAL

IF OBJECT_ID('TEMPDB..#CODPROMOCION_PB2') IS NOT NULL DROP TABLE #CODPROMOCION_PB2
SELECT DISTINCT PERIODO
            ,CADENA
            ,CODTIENDALOST
            ,CODFECHA
            ,CODTIENDA
            ,CODTICKET2
            ,CODMATERIAL
            ,CODTICKET2+CODMATERIAL LLAVE
INTO #CODPROMOCION_PB2
FROM #BONUS2  
WHERE PTOSCONSMATERIAL>0
GROUP BY PERIODO,CADENA,CODTIENDALOST,CODFECHA,CODTIENDA,CODTICKET2,CODMATERIAL,CODTICKET2+CODMATERIAL

IF OBJECT_ID('TEMPDB..#CODPROMOCION_PBTT') IS NOT NULL DROP TABLE #CODPROMOCION_PBTT
SELECT * 
INTO #CODPROMOCION_PBTT
FROM #CODPROMOCION_PB1
UNION
SELECT* FROM #CODPROMOCION_PB2

IF OBJECT_ID('TEMPDB..#BONUS3') IS NOT NULL DROP TABLE #BONUS3  
SELECT DISTINCT PERIODO
            ,CADENA
            ,CODTIENDALOST
            ,CODFECHA
            ,CODTIENDA
            ,CAJA
            ,TICKET
            ,HORA
            ,CODTICKET2
            ,CODMATERIAL
            ,PTOSACUMTICKET
            ,PTOSCONSMATERIAL
            ,UNIDPROMOMATERIAL
            ,CODTICKET2+CODMATERIAL LLAVE
INTO #BONUS3
FROM #BONUS2  
WHERE CODMATERIAL<>''
GROUP BY PERIODO,CADENA,CODTIENDALOST,CODFECHA,CODTIENDA,CAJA,TICKET,HORA,CODTICKET2,CODMATERIAL,PTOSACUMTICKET,PTOSCONSMATERIAL,UNIDPROMOMATERIAL,CODTICKET2+CODMATERIAL

ALTER TABLE #BONUS3  ADD CODPROMOCION_BONUS INT 

UPDATE #BONUS3  SET CODPROMOCION_BONUS=1 
UPDATE #BONUS3 SET CADENA = @COD_CADENA
FROM   #BONUS3 B 
INNER JOIN   #CODPROMOCION_PBTT A ON A.LLAVE=B.LLAVE

SELECT *
INTO TEMPORAL.DBO.IVB_BONUS2020_V2
FROM #BONUS3

--!
SELECT  SUM(PTOSACUMTICKET)
FROM    TEMPORAL.DBO.IVB_BONUS2020_V2

--PERIODO

IF OBJECT_ID('TEMPDB..#PERIODOS_ACT') IS NOT NULL DROP TABLE #PERIODOS_ACT
SELECT CAST(LEFT(CODFECHA,6) AS INT) PERIODO,  
ROW_NUMBER() OVER(ORDER BY LEFT(CODFECHA,6)) RN 
INTO #PERIODOS_ACT
FROM #FECHA 
GROUP BY LEFT(CODFECHA,6) ORDER BY LEFT(CODFECHA,6)

--DETALLES DESCRIPTIVOS DEL PRODUCTO

IF OBJECT_ID('TEMPDB..#MATERIAL') IS NOT NULL DROP TABLE #MATERIAL
SELECT distinct CodMaterial
INTO #MATERIAL
FROM [G200603SVHB8\IC_DATOS].MAESTROS.DBO.VW_DETAILS_MATERIAL A
INNER JOIN  Stage.DBO.TRX_TICKET B
ON  A.CODMATERIAL = B.COD_MATERIAL
WHERE   B.COD_TIPO_CLIENTE = 1  AND B.COD_DIA = (SELECT * FROM #FECHA)
        AND B.COD_CADENA = @COD_CADENA

--SELECT count(distinct CodMaterial)cant
--FROM #MATERIAL

        
--SELECT count(distinct CodMaterial)cant
--INTO #MATERIAL2
--FROM [G200603SVHB8\IC_DATOS].MAESTROS.DBO.VW_DETAILS_MATERIAL A
--977412


CREATE NONCLUSTERED INDEX IDX_MATERIAL ON #MATERIAL(CodMaterial)

PRINT 'OBTENIENDO DATA HISTORICA IC_TICKET ' + convert(varchar,getdate())
IF OBJECT_ID('TEMPDB..#IC_TICKET_HIST')IS NOT NULL DROP TABLE #IC_TICKET_HIST	

	SELECT A.[COD_DIA] COD_DIA
	,CAST(LEFT(A.[COD_DIA],6) AS INT) COD_MES 
	,CASE WHEN @CADENA = 'WONG' THEN '01' ELSE '02' END CADENA
	,A. COD_TIPO_CLIENTE, 
	A.[COD_TIENDA] CODTIENDA
	,A.[COD_CLIENTE] CODPERSONA
	,A.[COD_TICKET] CODTICKET
	,A.[NUM_TARJETA_BONUS] BONUS
	,A.[COD_MATERIAL] CODMATERIAL
	,SUM(A.[MTO_VENTA_BRUTA] )VTABS
	,SUM( A.[MTO_VENTA_NETA]) VTANETA
	,CASE WHEN A.COD_TIPO_CLIENTE = 1 THEN SUM(MTO_VENTA_NETA) ELSE 0 END VENTA_NETA_IDENTIFICADA
	,SUM( A.[MTO_MARGEN]) MARGEN
	,SUM(A.[CNT_VENTA]) VTAQ
	,SUM(A.[MTO_DESCUENTO]) DSCTO
	,A.[MTO_TICKET] MONTOTICKET,
	((CASE WHEN A.[COD_TIPO_CLIENTE] = 1 THEN 1  ELSE 0 END)*CAST(A.[MTO_TICKET]/NULLIF(7.5,0) AS INT )) MONTO_PTO_NATURAL,
	CAST((SUM(A.[MTO_VENTA_BRUTA]))/NULLIF(A.[MTO_TICKET],0) AS  FLOAT) PART_TRX,
	((CASE WHEN A.[COD_TIPO_CLIENTE] = 1 THEN 1  ELSE 0 END)*(CAST( CAST((A.[MTO_TICKET]/NULLIF(7.5,0))AS INT )*(CAST((SUM(A.[MTO_VENTA_BRUTA])     )/NULLIF(A.[MTO_TICKET],0) AS FLOAT))  AS  FLOAT)))  PTO_ENTREGADO,
	SUM((CASE WHEN A.[COD_PROMOCION] = 1 THEN 1  ELSE 0 END)*A.[MTO_DESCUENTO] ) DSCTO_BONUS
	INTO #IC_TICKET_HIST
    FROM [STAGE].[DBO].[TRX_TICKET] A WITH(NOLOCK)
	INNER JOIN #MATERIAL C ON   A.[COD_MATERIAL]=C.CODMATERIAL
	WHERE A.[COD_CADENA] = @COD_CADENA
	AND COD_DIA IN (SELECT * FROM #FECHA) --COD_TIPO_CLIENTE <> 3
	GROUP BY A.[COD_DIA],A. COD_TIPO_CLIENTE,A.[COD_TIENDA],A.[COD_CLIENTE],A.[COD_TICKET]  ,A.[MTO_TICKET],A.           [NUM_TARJETA_BONUS] ,A.[COD_MATERIAL] 

----!
--SELECT  COUNT(*)
--FROM    #ic_ticket_hist



--Queda fuera provisionalmente DSCTONETO_TOTALBONUS_1 FLOAT
ALTER TABLE #IC_TICKET_HIST ADD  CASO_VALIDO INT ,DSCTONETO_MEGA  DECIMAL(10,3) ,DSCTONETO_PROMOBONUS  DECIMAL(10,3) , IGV  DECIMAL(10,3) 
ALTER TABLE  #IC_TICKET_HIST ADD DSCTONETO_MEGA2  DECIMAL(10,3) ,DSCTONETO_PROMOBONUS2  DECIMAL(10,3) 
ALTER TABLE #IC_TICKET_HIST ADD  DSCTONETO_MEGA_V2    DECIMAL(10,3) , DSCTONETO_PROMOBONUS_V2  DECIMAL(10,3) 
ALTER TABLE #IC_TICKET_HIST ADD SOLESPUNTOS  DECIMAL(10,3) 
ALTER TABLE #IC_TICKET_HIST ADD CANJE_VALIDO CHAR(50)

IF OBJECT_ID('TEMPDB..#TRXBONUS')IS NOT NULL DROP TABLE #TRXBONUS
SELECT DISTINCT [COD_TICKET] CODTICKET, [COD_MATERIAL] CODMATERIAL,[COD_TICKET]+[COD_MATERIAL] LLAVE  
INTO #TRXBONUS 
FROM STAGE.DBO.TRX_TICKET A WITH(NOLOCK)
INNER JOIN #FECHA B ON A.[COD_DIA] = B.CODFECHA
INNER JOIN #MATERIAL C ON   A.[COD_MATERIAL]=C.CODMATERIAL
WHERE  A.[COD_CADENA] = @COD_CADENA AND [COD_PROMOCION] = 1 
GROUP BY [COD_TICKET] , [COD_MATERIAL]  ,[COD_TICKET]+[COD_MATERIAL] 


IF OBJECT_ID('TEMPDB..#TRXMEGA')IS NOT NULL DROP TABLE #TRXMEGA
SELECT DISTINCT [COD_TICKET] CODTICKET, [COD_MATERIAL] CODMATERIAL,[COD_TICKET]+[COD_MATERIAL] LLAVE
    ,SUM((CASE WHEN A.[COD_PROMOCION] IN ('139229','139231','139232','139233','139234','139235','139236','139251') THEN 1 ELSE 0 END)*A.[MTO_DESCUENTO] ) DSCTO_MEGA  
INTO #TRXMEGA 
FROM STAGE.DBO.TRX_TICKET A WITH(NOLOCK)
INNER JOIN #FECHA B ON A.[COD_DIA] = B.CODFECHA
WHERE A.[COD_CADENA] = @COD_CADENA AND [COD_PROMOCION] IN ('139229','139231','139232','139233','139234','139235','139236','139251') 
  AND [COD_MATERIAL] IN ('000000000000732557','000000000000732558','000000000000732559','000000000000732560','000000000000732561','000000000000732562','000000000000732563'        ,'000000000000732564')
GROUP BY [COD_TICKET] , [COD_MATERIAL]  ,[COD_TICKET]+[COD_MATERIAL] 
-- LOS VARIABLES

ALTER TABLE #IC_TICKET_HIST ADD  PTOSACUMTICKET INT,PTOSCONSMATERIAL INT ,UNIDPROMOMATERIAL DECIMAL(10,3) ,COD_PROMO_BONUS_TRX INT  ,CODPROMO_MEGA INT, DESCTMEGA FLOAT
UPDATE #IC_TICKET_HIST SET  PTOSACUMTICKET =0,PTOSCONSMATERIAL=0,UNIDPROMOMATERIAL=0,COD_PROMO_BONUS_TRX=0,CODPROMO_MEGA=0,DESCTMEGA=0

UPDATE #IC_TICKET_HIST SET PTOSACUMTICKET = B.PTOSACUMTICKET
FROM TEMPORAL.DBO.IVB_BONUS2020_V2  B
INNER JOIN #IC_TICKET_HIST A ON A.CADENA=B.CADENA AND A.CODMATERIAL=B.CODMATERIAL AND A.CODTICKET=B.CODTICKET2

UPDATE #IC_TICKET_HIST SET PTOSCONSMATERIAL = B.PTOSCONSMATERIAL
FROM TEMPORAL.DBO.IVB_BONUS2020_V2  B
INNER JOIN #IC_TICKET_HIST A ON A.CADENA= B.CADENA AND A.CODMATERIAL=B.CODMATERIAL AND A.CODTICKET=B.CODTICKET2

--!
SELECT  COUNT(*)
FROM    #IC_TICKET_HIST

UPDATE #IC_TICKET_HIST SET UNIDPROMOMATERIAL = B.UNIDPROMOMATERIAL
FROM TEMPORAL.DBO.IVB_BONUS2020_V2  B
INNER JOIN #IC_TICKET_HIST A ON A.CADENA=B.CADENA AND A.CODMATERIAL=B.CODMATERIAL AND A.CODTICKET=B.CODTICKET2

UPDATE #IC_TICKET_HIST SET COD_PROMO_BONUS_TRX = 1
FROM #TRXBONUS  B
INNER JOIN #IC_TICKET_HIST A ON A.CODMATERIAL=B.CODMATERIAL AND A.CODTICKET=B.CODTICKET

UPDATE #IC_TICKET_HIST SET CODPROMO_MEGA = 1, DESCTMEGA=B.DSCTO_MEGA
FROM #TRXMEGA  B
INNER JOIN #IC_TICKET_HIST A ON A.CODMATERIAL=B.CODMATERIAL AND A.CODTICKET=B.CODTICKET

PRINT 'OBTENIENDO DATA HISTORICA IC_TICKET ' + CONVERT(VARCHAR,GETDATE())
--CANJE SISTEMAS ( EN LA TRANSAFORMACION SE TOMO TANTO LAS CODPROMOCION 1 Y DONDE PTOSCANJEADOSERA MAYOR A CERO

IF OBJECT_ID('TEMPDB..#TRX_B_CANJE_ACT')IS NOT NULL DROP TABLE #TRX_B_CANJE_ACT	
SELECT DISTINCT CODTICKET2 CODTICKET, CODMATERIAL,[CODTICKET2]+[CODMATERIAL] LLAVE  
INTO #TRX_B_CANJE_ACT 
FROM TEMPORAL.DBO.IVB_BONUS2020_V2 
WHERE  [CADENA] =@CADENA  AND CODPROMOCION_BONUS=1 
GROUP BY CODTICKET2  , CODMATERIAL  ,[CODTICKET2]+[CODMATERIAL ]

PRINT 'OBTENIENDO DATA HISTORICA  : ' + CONVERT(VARCHAR,GETDATE(),112)

--*****************************************	
--TRX TOTALES ACTUALES
IF OBJECT_ID('TEMPDB..#TRX_TOTALES_ACT')IS NOT NULL DROP TABLE #TRX_TOTALES_ACT	
SELECT DISTINCT CODTICKET,  CODMATERIAL,[CODTICKET]+[CODMATERIAL] LLAVE  
INTO #TRX_TOTALES_ACT
FROM #IC_TICKET_HIST 
GROUP BY CODTICKET,  CODMATERIAL,[CODTICKET]+[CODMATERIAL] 

--1 FIDELIDAD 

--NIVEL TICKET

IF OBJECT_ID('TEMPDB..#TRX_ACT')IS NOT NULL DROP TABLE #TRX_ACT
SELECT DISTINCT CODTICKET
INTO #TRX_ACT
FROM #IC_TICKET_HIST 
GROUP BY CODTICKET

IF OBJECT_ID('TEMPDB..#B_CANJE_ACT_NIVELTRX')IS NOT NULL DROP TABLE #B_CANJE_ACT_NIVELTRX
SELECT  CODFECHA,  PERIODO,  CADENA,   CODTIENDA, CODTICKET2 CODTICKET, 
    PTOSACUMTICKET
INTO  #B_CANJE_ACT_NIVELTRX	
FROM  TEMPORAL.DBO.IVB_BONUS2020_V2
WHERE  CODFECHA IN (SELECT codfecha FROM #FECHA)
   AND CODTICKET2  IN (SELECT DISTINCT CODTICKET FROM #TRX_ACT)
GROUP BY  CODFECHA,  PERIODO,  CADENA,   CODTIENDA, CODTICKET2 , PTOSACUMTICKET



IF OBJECT_ID('TEMPDB..#IC_TICKET_HIST_NIVELTRX')IS NOT NULL DROP TABLE #IC_TICKET_HIST_NIVELTRX
SELECT  COD_DIA,  COD_MES,  CADENA, COD_TIPO_CLIENTE,  CODTIENDA, CODPERSONA, CODTICKET, BONUS,
SUM(VTANETA) VTANS
,CASE WHEN COD_TIPO_CLIENTE = 1 THEN SUM(VTANETA) ELSE 0 END VENTA_NETA_IDENTIFICADA,
SUM(MARGEN) MGN, SUM(VTABS) VTABS, SUM(DSCTO) DSCTO,
MONTO_PTO_NATURAL,	SUM(PTO_ENTREGADO ) PTO_ENTREGADO, PTOSACUMTICKET
INTO #IC_TICKET_HIST_NIVELTRX	
FROM #IC_TICKET_HIST 
GROUP BY COD_DIA,  COD_MES,  CADENA, COD_TIPO_CLIENTE,  CODTIENDA, CODPERSONA, 
CODTICKET, BONUS,MONTO_PTO_NATURAL, PTOSACUMTICKET,VTANETA

CREATE NONCLUSTERED INDEX IDX ON #IC_TICKET_HIST (CODMATERIAL)
CREATE NONCLUSTERED INDEX IDX2 ON #IC_TICKET_HIST (COD_MES)
CREATE NONCLUSTERED INDEX IDX3 ON #IC_TICKET_HIST ( MONTOTICKET)

-- OUTPUT FIDELIDAD
--===========================
IF OBJECT_ID('TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD')IS NOT NULL DROP TABLE TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD	
SELECT  COD_DIA
,COD_MES
,CODTIENDA
,B.CODMATERIAL
,CODPERSONA
,COD_TIPO_CLIENTE
,'1' ID_TIPO_BONUS
,SUM(PTO_ENTREGADO)PTO_ENTREGADO
,SUM(VTANETA)VTANETA
,CASE WHEN COD_TIPO_CLIENTE = 1 THEN SUM(VTANETA) ELSE 0 END VENTA_NETA_IDENTIFICADA
,CODTICKET
INTO TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD       
FROM #IC_TICKET_HIST B
INNER JOIN #MATERIAL C ON B.CODMATERIAL=C.CODMATERIAL
GROUP BY  COD_DIA,COD_MES,CADENA,B.CODMATERIAL,COD_TIPO_CLIENTE,CODPERSONA,CODTICKET,CODTIENDA,COD_TIPO_CLIENTE,VTANETA


--**************************************************************+
--CANJE	
--TXRBONUS Y TRXMEGA ES DE ICTICKET
--FALTA INDICE CADENA,CODFECHA,CODTICKET,CODMATERIAL
IF OBJECT_ID('TEMPDB..#TRX_SISTEMAS_TOTAL')IS NOT NULL DROP TABLE #TRX_SISTEMAS_TOTAL
SELECT DISTINCT CODTICKET2 CODTICKET2, CODMATERIAL,[CODTICKET2]+CODMATERIAL LLAVE,CADENA
INTO #TRX_SISTEMAS_TOTAL  
FROM TEMPORAL.DBO.IVB_BONUS2020_V2  
WHERE CODFECHA IN (SELECT codfecha FROM #FECHA)
   AND CODPROMOCION_BONUS=1 
GROUP BY CODTICKET2  , CODMATERIAL,[CODTICKET2]+CODMATERIAL  ,CADENA

IF OBJECT_ID('TEMPDB..#TRX_ACT_CANJE')IS NOT NULL DROP TABLE #TRX_ACT_CANJE
SELECT DISTINCT LLAVE,CODTICKET,CODMATERIAL 
INTO #TRX_ACT_CANJE
FROM  #TRXBONUS
UNION
SELECT DISTINCT LLAVE,CODTICKET,CODMATERIAL FROM  #TRXMEGA 
UNION
SELECT DISTINCT LLAVE,CODTICKET,CODMATERIAL FROM  #TRX_B_CANJE_ACT 	
WHERE   CAST(SUBSTRING(CODTICKET,6,8) AS VARCHAR(8)) IN (SELECT codfecha FROM #FECHA)

IF OBJECT_ID('TEMPDB..#TRX_BONUSMEGA')IS NOT NULL DROP TABLE #TRX_BONUSMEGA
SELECT DISTINCT LLAVE,CODTICKET,CODMATERIAL 
INTO #TRX_BONUSMEGA
FROM  #TRXBONUS
UNION
SELECT DISTINCT LLAVE,CODTICKET,CODMATERIAL FROM  #TRXMEGA 

ALTER TABLE  #TRX_ACT_CANJE ADD MEGA INT , PROMOBONUS INT,TRX_ICTICKET INT, TRX_SISTEMAS INT,TRX_IC_OTROCONCEPTO INT,TRX_SISTEMAS_PROMOCANJE INT

UPDATE #TRX_ACT_CANJE SET MEGA =0, PROMOBONUS =0,TRX_ICTICKET =0, TRX_SISTEMAS =0,TRX_IC_OTROCONCEPTO=0,TRX_SISTEMAS_PROMOCANJE=0

UPDATE 	#TRX_ACT_CANJE SET MEGA =1 WHERE LLAVE IN (SELECT LLAVE FROM #TRXMEGA )
UPDATE #TRX_ACT_CANJE SET PROMOBONUS =1 WHERE LLAVE IN (SELECT LLAVE FROM #TRXBONUS )
UPDATE #TRX_ACT_CANJE SET  TRX_ICTICKET =1 WHERE  LLAVE IN (SELECT LLAVE FROM #TRX_TOTALES_ACT )
UPDATE #TRX_ACT_CANJE SET  TRX_SISTEMAS =1 WHERE LLAVE IN (SELECT LLAVE FROM #TRX_SISTEMAS_TOTAL )
UPDATE #TRX_ACT_CANJE SET  TRX_SISTEMAS_PROMOCANJE =1 WHERE LLAVE IN (SELECT LLAVE FROM #TRX_B_CANJE_ACT )
UPDATE #TRX_ACT_CANJE SET  TRX_IC_OTROCONCEPTO=1 WHERE LLAVE IN (SELECT LLAVE FROM #TRX_TOTALES_ACT ) AND LLAVE NOT IN (SELECT LLAVE FROM #TRX_BONUSMEGA)   

UPDATE #IC_TICKET_HIST SET CASO_VALIDO =0 

UPDATE #IC_TICKET_HIST SET CASO_VALIDO =1 WHERE CADENA= @COD_CADENA AND CODTICKET+CODMATERIAL IN (SELECT LLAVE FROM #TRX_ACT_CANJE WHERE TRX_IC_OTROCONCEPTO=0 AND TRX_SISTEMAS=1 AND TRX_ICTICKET=1 AND PROMOBONUS=1) 

UPDATE #IC_TICKET_HIST SET  IGV =(1-VTANETA/NULLIF(VTABS,0))
UPDATE #IC_TICKET_HIST SET  DSCTONETO_MEGA  = ISNULL((DESCTMEGA)*(1-IGV),0)
UPDATE #IC_TICKET_HIST SET  DSCTONETO_PROMOBONUS = ISNULL((DSCTO_BONUS)*(1-IGV),0)

UPDATE #IC_TICKET_HIST SET  DSCTONETO_MEGA2 = ISNULL(
CASE WHEN VTANETA-VTABS = 0 THEN (DESCTMEGA)
ELSE (DESCTMEGA)/1.18 
END
,0) 

UPDATE #IC_TICKET_HIST SET  DSCTONETO_PROMOBONUS2 = ISNULL(
CASE WHEN VTANETA-VTABS = 0 THEN (DSCTO_BONUS )
ELSE (DSCTO_BONUS )/1.18 
END 
,0)

UPDATE #IC_TICKET_HIST SET DSCTONETO_PROMOBONUS_V2 =0


DECLARE @VALORBONUS DECIMAL(10,2) = 
(
SELECT 
--ISNULL(SUM(DSCTONETO_MEGA2),0) DSCTONETO_MEGA2
ISNULL(SUM(DSCTONETO_PROMOBONUS2),0) DSCTONETO_PROMOBONUS2  --se toma para el valor calculado
FROM #IC_TICKET_HIST 
WHERE CASO_VALIDO = 1
)

--=============================
--cambiar valor por resultado de cubo loyalty

DECLARE @COD_CADENA2 CHAR(1) = CASE WHEN @COD_CADENA = '01' THEN '1' ELSE '2' END

DECLARE @VALOR2 DECIMAL(10,2) = (SELECT  SUM(a11.MTO_VENTA_NETA_LOYALTY)  MONTOVENTADESCUENTOLOYALTY
FROM	"g200603svhb5\ic_dw".DW_CENCOFCIC.DBO.FACT_VENTA_GA a11
join	"g200603svhb5\ic_dw".DW_CENCOFCIC.DBO.DIM_DIA a12 on (a11.SK_DIA = a12.SK_DIA)
join	"g200603svhb5\ic_dw".DW_CENCOFCIC.DBO.DIM_TIENDA a13 on (a13.SK_TIENDA = a11.SK_TIENDA)
where	a12.SK_DIA IN (SELECT * FROM #FECHA) AND a13.SK_CADENA = @COD_CADENA2) * -1

--****HASTA AQUI TODO JUNTO : LOS PUNTOS EDITARLOS DE MICRO 
UPDATE #IC_TICKET_HIST SET  DSCTONETO_MEGA_V2  =(DSCTONETO_MEGA2)--MANTIENEN SEGUN EJERCICIO
UPDATE #IC_TICKET_HIST SET  DSCTONETO_PROMOBONUS_V2 =((DSCTONETO_PROMOBONUS2)/ @VALORBONUS)* @VALOR2 WHERE CASO_VALIDO =1
--UPDATE #IC_TICKET_HIST SET SOLESPUNTOS=0
UPDATE #IC_TICKET_HIST SET SOLESPUNTOS= ISNULL(0.02625*PTOSCONSMATERIAL,0)
UPDATE #IC_TICKET_HIST SET CANJE_VALIDO = '1' FROM #TRX_ACT_CANJE A INNER JOIN #IC_TICKET_HIST B ON A.CODMATERIAL = B.CODMATERIAL
                                        WHERE TRX_SISTEMAS=1 AND TRX_ICTICKET=1 AND PROMOBONUS =1 AND MEGA=0

UPDATE #IC_TICKET_HIST SET CANJE_VALIDO = '0' WHERE CANJE_VALIDO IS NULL

UPDATE #IC_TICKET_HIST SET DSCTONETO_PROMOBONUS_V2 = 0
WHERE   DSCTONETO_PROMOBONUS_V2 IS NULL

/*,

OUTPUT DE CANJE
===================================================
*/
IF OBJECT_ID('TEMPORAL.DBO.IC_TICKET_HIST_CANJE')IS NOT NULL DROP TABLE TEMPORAL.DBO.IC_TICKET_HIST_CANJE	
SELECT COD_DIA,COD_MES,CODTIENDA,B.CODMATERIAL,CODTICKET,CODPERSONA,COD_TIPO_CLIENTE,'0' ID_TIPO_BONUS,
SUM(DSCTO_BONUS)DSCTO_BONUS,
SUM(DSCTONETO_PROMOBONUS_V2)DSCTONETO,
SUM(PTOSCONSMATERIAL)PTOSCONSMATERIAL,
SUM(VTANETA)VTANETA,
CASE WHEN COD_TIPO_CLIENTE = 1 THEN SUM(VTANETA) ELSE 0 END VENTA_NETA_IDENTIFICADA
INTO TEMPORAL.DBO.IC_TICKET_HIST_CANJE
FROM #IC_TICKET_HIST B
INNER JOIN #MATERIAL C ON B.CODMATERIAL=C.CODMATERIAL
WHERE  CODTICKET+B.CODMATERIAL IN (SELECT LLAVE FROM #TRX_ACT_CANJE WHERE TRX_SISTEMAS =1 AND TRX_ICTICKET=1 AND PROMOBONUS =1 AND MEGA=0 )
GROUP BY   COD_DIA,COD_MES,B.CODMATERIAL,CODTICKET,CODPERSONA,CODTIENDA,COD_TIPO_CLIENTE

--UPDATE TEMPORAL.DBO.IC_TICKET_HIST_CANJE
--SET	DSCTO_BONUS = CONVERT(DECIMAL(7,4),CAST(DSCTO_BONUS AS CHAR(10))) FROM TEMPORAL.DBO.IC_TICKET_HIST_CANJE

--UPDATE TEMPORAL.DBO.IC_TICKET_HIST_CANJE
--SET	DSCTONETO = CONVERT(DECIMAL(6,4),CAST(DSCTONETO AS CHAR(7))) FROM TEMPORAL.DBO.IC_TICKET_HIST_CANJE

--UPDATE TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD
--SET	PTO_ENTREGADO = CONVERT(DECIMAL(10,3),CAST(PTO_ENTREGADO AS CHAR(14))) FROM TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD

UPDATE TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD SET PTO_ENTREGADO = 0 WHERE PTO_ENTREGADO IS NULL

ALTER TABLE TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD ALTER COLUMN PTO_ENTREGADO DECIMAL(10,3) NOT NULL

--!
select  SUM(PTOSCONSMATERIAL),SUM(DSCTO_BONUS),SUM(DSCTONETO)
from    TEMPORAL.DBO.IC_TICKET_HIST_CANJE
229283	8901.66	7796.526

SELECT  SUM(VENTA_NETA_IDENTIFICADA),SUM(VTANETA),SUM(PTO_ENTREGADO)
FROM    TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD

3753954.09	4588215.96	564264.418
4,549,726.88

DECLARE @CADENA CHAR(5) = 'WONG'
DECLARE @FECHAINI INT = 20200401
DECLARE @FECHAFIN INT = 20200401

---- DECLARAMOS VARIABLES
DECLARE @COD_CADENA CHAR(2) = CASE WHEN @CADENA = 'WONG' THEN '01' ELSE '02' END


--********** TABLAS FINALES ******************************************
--============================================================================

INSERT INTO STAGE.[dbo].[TRX_TICKET_BONUS]
SELECT	 
A.COD_DIA
,A.COD_MES
,@COD_CADENA AS CADENA
,A.CODTIENDA AS COD_TIENDA
,A.CODMATERIAL AS COD_MATERIAL
,A.CODTICKET AS COD_TICKET
,A.CODPERSONA AS COD_CLIENTE
,A.DSCTO_BONUS AS MTO_DSCTO_BONUS_BRUTO
,A.DSCTONETO AS MTO_DSCTO_BONUS_NETO
,A.VENTA_NETA_IDENTIFICADA
,A.VTANETA
,A.PTOSCONSMATERIAL AS CNT_PUNTO_REDIMIDO
,0 CNT_PUNTO_ACUMULADO
,A.ID_TIPO_BONUS
FROM	TEMPORAL.DBO.IC_TICKET_HIST_CANJE A
WHERE   A.COD_DIA IN (SELECT * FROM #FECHA)
UNION ALL
SELECT	 
B.COD_DIA
,B.COD_MES
,@COD_CADENA AS CADENA
,B.CODTIENDA AS COD_TIENDA
,B.CODMATERIAL AS COD_MATERIAL
,B.CODTICKET AS COD_TICKET
,B.CODPERSONA AS COD_CLIENTE
,0 MTO_DSCTO_BONUS_BRUTO
,0 MTO_DSCTO_BONUS_NETO
,B.VENTA_NETA_IDENTIFICADA
,B.VTANETA
,0 CNT_PUNTO_REDIMIDO
,B.PTO_ENTREGADO AS CNT_PUNTO_ACUMULADO
,B.ID_TIPO_BONUS
FROM	TEMPORAL.DBO.IC_TICKET_HIST_FIDELIDAD B
WHERE   B.COD_DIA IN (SELECT * FROM #FECHA)


INSERT INTO "g200603svhb5\ic_dw".DW_CENCOFCIC.DBO.FACT_TICKET_BONUS
SELECT		A.[COD_DIA] AS SK_DIA,
	A.[COD_MES] AS SK_MES,
	B.[SK_TIENDA],
	C.[SK_MATERIAL],
	A.[MTO_DSCTO_BONUS_BRUTO],
	A.[MTO_DSCTO_BONUS_NETO],
	A.[MTO_VENTA_NETA_BONUS_IDEN],
	A.[MTO_VENTA_NETA_BONUS],
	A.[CNT_PUNTO_REDIMIDO],
	A.[CNT_PUNTO_ACUMULADO],
	A.[ID_TIPO_BONUS]
FROM		STAGE.[dbo].[TRX_TICKET_BONUS]	A 
LEFT JOIN	"g200603svhb5\ic_dw".DW_CENCOFCIC.DBO.DIM_MATERIAL C ON A.COD_MATERIAL	= C.ID_MATERIAL
LEFT JOIN   [g200603svhb5\ic_dw].[DW_CENCOFCIC].[dbo].[DIM_TIENDA] B ON A.COD_TIENDA = B.ID_TIENDA
WHERE		A.COD_DIA IN (SELECT * FROM #FECHA)
            AND A.COD_CADENA = @COD_CADENA