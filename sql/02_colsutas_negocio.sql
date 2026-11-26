
-- ============================================================
-- Proyecto: Análisis de ventas con AdventureWorksLT (SQL Server)
-- Archivo: consultas de negocio
-- ============================================================
USE AdventureWorksLT2025
GO

-- ---------- Q1: ¿Qué categorías de producto generan más ingresos? ------------
-- Tablas: SalesOrderDetail, Product, ProductCategory
-- Nota: LineTotal ya incluye el descuento aplicado.

SELECT pc.Name AS categoria,
	   CAST(SUM(d.LineTotal) AS DECIMAL(12,2)) AS ingresos
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p		ON d.ProductID = p.ProductID
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.ProductCategoryID, pc.Name
ORDER BY ingresos DESC;

-- Conclusión:
-- Touring Bikes lidera los ingresos ($220.655), un 20,49% más que Road Bikes ($183.130).
-- Mountain Bikes ($170.825) factura 3,1 veces lo de Mountain Frames ($54.949).
-- Las categorías de accesorios y componentes aportan montos muy chicos.

-- ---------- Q1b: ¿Y por categoría padre? ----------
-- Tablas: SalesOrderDetail, Product, ProductCategory (unida consigo misma: self join)

SELECT pcp.Name AS categoria_padre,
	   CAST(SUM(d.LineTotal)AS DECIMAL(12,2)) AS ingresos,
	   CAST(SUM(d.LineTotal) * 100.0 / SUM(SUM(d.LineTotal)) OVER () AS DECIMAL(5,2)) AS pct_del_total
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p			 ON d.ProductID = p.ProductID
JOIN SalesLT.ProductCategory pc  ON p.ProductCategoryID = pc.ProductCategoryID
JOIN SalesLT.ProductCategory pcp ON pc.ParentProductCategoryID = pcp.ProductCategoryID
GROUP BY pcp.Name, pcp.ProductCategoryID
ORDER BY ingresos DESC;

-- Conclusión: 
-- Bikes concentra el 81% de los ingresos ($574.611), seguida de Components (15,7%).
-- Clothing y Accessories juntas no llegan al 4%, lo que indica una fuerte
-- dependencia de las bicicletas completas.

-- ---------- Q2: ¿Cuales son los 10 productos mas vendidos? ------------

-- Q2a: por ingresos
SELECT TOP 10 p.Name AS producto,
		CAST(SUM(d.LineTotal) AS DECIMAL(12,2)) AS ingresos
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p ON d.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY ingresos DESC;

-- Q2b: por unidades
SELECT TOP 10 p.Name AS producto,
		CAST(SUM(d.OrderQty) AS DECIMAL (12,2)) AS unidades_vendidas
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p ON d.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY unidades_vendidas DESC, p.Name;

-- Conclusión:
-- El top 10 por ingresos está formado solo por bicicletas (Touring-1000, Mountain-200 y Road-350-W)
-- lidera Touring-1000 Blue, 60 ($37.191).
-- El top 10 por unidades son productos de ropa y accesorios, liderado por Classic Vest, S (87 unidades)
-- Ningun producto coincide en ambos top 10, solo Road-350-W Yellow, 48 aparece en los dos si se amplía a top 13 
-- los productos que más se venden no son los que más ingresos generan.
-- Los accesorios dan volumen; el ingreso depende de pocas bicicletas de alto valor.

-- ---------- Q3: ¿Qué clientes compraron y cuáles nunca? ------------

SELECT COUNT(DISTINCT c.CustomerID) AS total_clientes,
	   COUNT(DISTINCT soh.customerID) AS clientes_que_compraron,
	   COUNT(DISTINCT CASE WHEN soh.CustomerID IS NULL THEN c.CustomerID END) AS clientes_que_no_compraron,
	   ROUND(COUNT(DISTINCT soh.CustomerID) * 100.0
			 / COUNT(DISTINCT c.CustomerID), 2) AS pct_compraron
FROM SalesLT.Customer c
LEFT JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID;

-- Conclusión:
-- Solo 32 de los 847 clientes (3,8%) realizaron compras; el 96,2% nunca compró.
-- Cada cliente que compró hizo un único pedido (32 pedidos, 32 clientes),
-- por lo que no hay compras recurrentes en los datos.
-- La base de clientes está casi inactiva


-- ---------- Q4: ¿Cómo se reparten las ventas por país y provincia? ------------

SELECT a.CountryRegion,
	   a.StateProvince,
	   COUNT(DISTINCT h.SalesOrderID) AS pedidos,
	   CAST(SUM(d.LineTotal) AS DECIMAL (12,2)) as ingresos,
	   CAST(SUM(d.LineTotal) / COUNT(DISTINCT h.SalesOrderID) AS DECIMAL(12,2)) AS ticket_promedio
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID
JOIN SalesLT.Address a			ON h.ShipToAddressID = a.AddressID
GROUP BY a.CountryRegion, a.StateProvince
ORDER BY ingresos DESC;

SELECT a.CountryRegion,
       COUNT(DISTINCT h.SalesOrderID) AS pedidos,
       CAST(SUM(d.LineTotal) AS DECIMAL(12,2)) AS ingresos,
       CAST(SUM(d.LineTotal) / COUNT(DISTINCT h.SalesOrderID) AS DECIMAL(12,2)) AS ticket_promedio
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID
JOIN SalesLT.Address a          ON h.ShipToAddressID = a.AddressID
GROUP BY a.CountryRegion
ORDER BY ingresos DESC;

-- Conclusión:
-- Reino Unido (solo Inglaterra) lidera los ingresos ($425.979, el 60% del total)
-- con 14 pedidos; Estados Unidos suma 18 pedidos pero $282.711 en total.
-- El ticket promedio de Reino Unido (~$30.400) es casi el doble que el de
-- Estados Unidos (~$15.700): menos pedidos, pero de mayor valor.
-- Dentro de EE.UU. se concentra en California ($254.562); los otros 4 estados
-- tienen un solo pedido cada uno.

-- ---------- Q5: ¿Cual es el margen de ganancia por categoría? ------------

SELECT pc.Name AS categoria,
	   CAST(SUM(d.LineTotal) AS DECIMAL(12,2)) AS ingresos,
	   CAST(SUM(p.StandardCost * d.OrderQty) AS DECIMAL (12,2)) AS costo_total,
	   CAST(SUM(d.LineTotal) - SUM(p.StandardCost * d.OrderQty) AS DECIMAL(12,2)) AS margen,
	   CAST((SUM(d.LineTotal) - SUM(p.StandardCost * d.OrderQty)) * 100.0
			 / SUM(d.LineTotal) AS DECIMAL (5,2)) AS margen_pct
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p ON d.ProductID = p.ProductID
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.ProductCategoryID, pc.Name
ORDER BY margen DESC;


SELECT CAST(SUM(d.LineTotal) AS DECIMAL(12,2)) AS ingresos_totales,
       CAST(SUM(d.LineTotal) - SUM(p.StandardCost * d.OrderQty) AS DECIMAL(12,2)) AS margen_total
FROM SalesLT.SalesOrderDetail d
JOIN SalesLT.Product p ON d.ProductID = p.ProductID;

-- Conclusión:
-- Con el costo estándar, el margen total es negativo (aprox. -$13.456, -1,9%).
-- Las tres categorías que más ingresan (Touring, Road y Mountain Bikes, 81% del total)
-- tienen margen negativo o casi nulo: Road Bikes -10,2% y Touring Bikes -4,2%.
-- Los mayores márgenes porcentuales están en accesorios (Bike Racks, Hydration Packs
-- y Gloves, 37,7%), pero aportan pocos ingresos.
-- Jerseys y Caps también venden por debajo del costo (-32% y -30%).
-- Salvedad: base de ejemplo; varios márgenes repiten el mismo porcentaje, lo que
-- sugiere que los precios fueron generados con una fórmula fija.

-- ---------- Q6: ¿Qué productos nunca se vendieron? ------------

SELECT COUNT(DISTINCT p.ProductID) AS total_productos,
	   COUNT(DISTINCT d.ProductID) AS productos_vendidos,
	   COUNT(DISTINCT CASE WHEN d.ProductID IS NULL THEN p.ProductID END) AS productos_sin_ventas,
	   CAST(COUNT(DISTINCT CASE WHEN d.ProductID IS NULL THEN p.ProductID END) * 100.0
			 / COUNT(DISTINCT p.ProductID) AS DECIMAL(5,2)) AS pct_sin_ventas
FROM SalesLT.Product p 
LEFT JOIN SalesLT.SalesOrderDetail d ON p.ProductID = d.ProductID;

-- Conclusión:
-- De los 295 productos del catálogo, 153 (51,9%) nunca se vendieron;
-- solo 142 registran ventas.
-- Más de la mitad del catálogo no generó ingresos en el período, lo que invita a
-- revisar si conviene depurarlo, promocionarlo o ajustar el stock.

SELECT pcp.Name AS categoria_padre,
       COUNT(DISTINCT p.ProductID) AS total_productos,
	   COUNT(DISTINCT CASE WHEN d.ProductID IS NULL THEN p.ProductID END) AS sin_ventas,
	   CAST(COUNT(DISTINCT CASE WHEN d.ProductID IS NULL THEN p.ProductID END) * 100.0
			 / COUNT(DISTINCT p.ProductID) AS DECIMAL(5,2)) AS pct_sin_ventas
FROM SalesLT.Product p
JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID
JOIN SalesLT.ProductCategory pcp ON pc.ParentProductCategoryID = pcp.ProductCategoryID
LEFT JOIN SalesLT.SalesOrderDetail d ON p.ProductID = d.ProductID
GROUP BY pcp.ProductCategoryID, pcp.Name
ORDER BY pct_sin_ventas DESC;

-- Conclusión:
-- Accessories es la categoría padre con mayor proporción de productos sin ventas
-- (72,4%: 21 de 29), seguida de Components (57,5%), Clothing (51,4%) y Bikes (38,1%).
-- En volumen, Components concentra 77 de los 153 productos sin ventas (50%).
-- Bikes, además de ser la que más ingresos genera (Q1b), es la que mejor rota
-- su catálogo: 60 de 97 productos se vendieron.