select * from reserva;



-- DESARROLLO PRUEBA3

-- FUNCIONES ALMACENADAS PARA EL PKG

--------------------------------------------------------------------------------
-- FN CALCULA EL TOTAL COSTO TOURS POR HUESPED USANDO ID_HUESPED  EN DOLARES 
-----------------------------------------------------(FUNCION ALMACENADA PL/SQL)
CREATE OR REPLACE FUNCTION  fn_calcula_tours (p_id_huesped IN NUMBER)
RETURN NUMBER
IS
v_total_tours NUMBER := 0;
BEGIN

SELECT 
NVL(SUM(t.valor_tour),0)
INTO v_total_tours
FROM 
huesped_tour ht
INNER JOIN tour t 
ON ht.id_tour = t.id_tour
WHERE ht.id_huesped = p_id_huesped;

RETURN v_total_tours; 

END fn_calcula_tours; 

--------------------------------------------------------------------------------
-- FUNCION RETORNA AGENCIA USANDO ID_HUESPED CON INSERT A TABLA reg_errores
-----------------------------------------------------(FUNCION ALMACENADA PL/SQL)
CREATE OR REPLACE FUNCTION  fn_retorna_agencia (p_id_huesped NUMBER)
RETURN VARCHAR2
IS
v_nom_agencia VARCHAR2(20); 
v_msg VARCHAR2 (200); 

BEGIN

SELECT 
a.nom_agencia
INTO 
v_nom_agencia
FROM huesped h
LEFT JOIN agencia a 
ON a.id_agencia = h.id_agencia
WHERE h.id_huesped = p_id_huesped; 

RETURN NVL(v_nom_agencia, 'NO REGISTRA AGENCIA'); 

EXCEPTION  
WHEN OTHERS THEN 
v_msg := SQLERRM; 

INSERT INTO reg_errores(
id_error, 
nomsubprograma, 
msg_error
) 
VALUES (sq_error.NEXTVAL, 'Funcion retornar agencia', v_msg); 

RETURN 'ERROR'; 

END fn_retorna_agencia;
/

--------------------------------------------------------------------------------
-- FUNCION PARA CALCULAR EL TOTAL DE CONSUMO DE CLIENTE EN DOLARES
-----------------------------------------------------(FUNCION ALMACENADA PL/SQL)

CREATE OR REPLACE FUNCTION fn_consumo_dolares (p_id_huesped NUMBER)
RETURN NUMBER 
IS 
v_consumo_huesped NUMBER;  

BEGIN 
SELECT 
NVL(monto_consumos, 0)
INTO 
v_consumo_huesped
FROM total_consumos 
WHERE id_huesped = p_id_huesped; 

RETURN v_consumo_huesped; 

END fn_consumo_dolares; 


--------------------------------------------------------------------------------
-- PACKAGE PARA GUARDAR CONTRUCTORES A USAR EN PROCEDIMIENTO ALMACENADO PRINCIPAL 
-----------------------------------------------------(PACKAGE  PL/SQL)


--SPEC 
CREATE OR REPLACE PACKAGE pkg_pagos_tour 
IS
v_total_tours_g NUMBER; 
FUNCTION  fn_calcula_tours (p_id_huesped IN NUMBER)
RETURN NUMBER; 

END pkg_pagos_tour; 

--BODY 
CREATE OR REPLACE PACKAGE BODY pkg_pagos_tour 
IS 
FUNCTION  fn_calcula_tours (p_id_huesped IN NUMBER)
RETURN NUMBER
IS
v_total_tours NUMBER := 0;
BEGIN

SELECT 
NVL(SUM(t.valor_tour),0)
INTO v_total_tours
FROM 
huesped_tour ht
INNER JOIN tour t 
ON ht.id_tour = t.id_tour
WHERE ht.id_huesped = p_id_huesped;

RETURN v_total_tours; 

END fn_calcula_tours; 

END pkg_pagos_tour; 


--------------------------------------------------------------------------------
--CASO 1: TRIGGERS
-----------------------------------------------(TRIGGERS PL/SQL)

CREATE OR REPLACE TRIGGER trg_modificar_cargos_huesped 
AFTER INSERT OR UPDATE OR DELETE ON consumo 
FOR EACH ROW

BEGIN 
IF INSERTING THEN 
UPDATE total_consumos
SET monto_consumos = NVL(monto_consumos,0) + :NEW.monto
WHERE id_huesped = :NEW.id_huesped; 

ELSIF UPDATING THEN 
UPDATE total_consumos 
SET monto_consumos =  NVL(monto_consumos,0) + (:NEW.monto - :OLD.monto)
WHERE id_huesped = :NEW.id_huesped;

ELSIF DELETING THEN 
UPDATE total_consumos
SET monto_consumos = NVL(monto_consumos,0) - :OLD.monto
WHERE id_huesped = :OLD.id_huesped;

END IF; 
END trg_modificar_cargos_huesped; 
/


--------------------------------------------------------------------------------
--CASO 2: PROCEDIMIENTO ALMACENADO CALCULO PAGOS
-----------------------------------------------(SP PL/SQL)

CREATE OR REPLACE PROCEDURE sp_generar_detalle_diario (
    p_fecha_proceso   DATE,
    p_valor_dolar     NUMBER
)
IS
    CURSOR c_huespedes IS
        SELECT 
            h.id_huesped,
            h.nom_huesped,
            h.appat_huesped,
            h.apmat_huesped,
            a.nom_agencia,
            NVL(hab.valor_habitacion,0) AS valor_hab,
            NVL(hab.valor_minibar,0) AS valor_minibar,
            NVL(tc.monto_consumos,0) AS consumo
        FROM huesped h
        LEFT JOIN agencia a
            ON h.id_agencia = a.id_agencia
        LEFT JOIN reserva r
            ON h.id_huesped = r.id_huesped
        LEFT JOIN detalle_reserva dr
            ON r.id_reserva = dr.id_reserva
        LEFT JOIN habitacion hab
            ON dr.id_habitacion = hab.id_habitacion
        LEFT JOIN total_consumos tc
            ON h.id_huesped = tc.id_huesped
        WHERE (r.ingreso + r.estadia) = p_fecha_proceso;

    v_nombre               VARCHAR2(200);
    v_alojamiento          NUMBER;
    v_valor_personas       NUMBER := 35000 / p_valor_dolar; -- Convertido a dólares
    v_consumo_total        NUMBER;
    v_descuento_consumo    NUMBER;
    v_descuento_agencia    NUMBER;
    v_subtotal             NUMBER;
    v_total_dolares        NUMBER;
    v_total_pesos          NUMBER;

BEGIN
    -- Truncar tabla de resultados
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_diario_huespedes';

    -- Truncar tabla de errores
    EXECUTE IMMEDIATE 'TRUNCATE TABLE reg_errores';

    FOR r IN c_huespedes LOOP

        -- Nombre completo
        v_nombre := r.nom_huesped || ' ' 
                 || r.appat_huesped || ' ' 
                 || r.apmat_huesped;

        -- Alojamiento (en dólares)
        v_alojamiento := r.valor_hab + r.valor_minibar;

        -- Consumo total = consumos + tours
        v_consumo_total := r.consumo + fn_calcula_tours(r.id_huesped);

        -- Subtotal (en dólares)
        v_subtotal := v_alojamiento + v_consumo_total + v_valor_personas;

        -- Descuento por consumo (regla inventada si consumo > 300 USD)
        IF v_consumo_total > 300 THEN
            v_descuento_consumo := v_consumo_total * 0.05;
        ELSE
            v_descuento_consumo := 0;
        END IF;

        -- Descuento por agencia
        IF r.nom_agencia = 'VIAJES ALBERTI' THEN
            v_descuento_agencia := v_subtotal * 0.12;
        ELSE
            v_descuento_agencia := 0;
        END IF;

        -- Total en dólares
        v_total_dolares := v_subtotal - v_descuento_consumo - v_descuento_agencia;

        -- Conversión a pesos y redondeo
        v_total_pesos := ROUND(v_total_dolares * p_valor_dolar);

        -- Insertar resultado
        INSERT INTO detalle_diario_huespedes (
            id_huesped,
            nombre,
            agencia,
            alojamiento,
            consumos,
            subtotal_pago,
            descuento_consumos,
            descuentos_agencia,
            total
        )
        VALUES (
            r.id_huesped,
            v_nombre,
            r.nom_agencia,
            ROUND(v_alojamiento * p_valor_dolar),
            ROUND(v_consumo_total * p_valor_dolar),
            ROUND(v_subtotal * p_valor_dolar),
            ROUND(v_descuento_consumo * p_valor_dolar),
            ROUND(v_descuento_agencia * p_valor_dolar),
            v_total_pesos
        );

    END LOOP;
    COMMIT;
END sp_generar_detalle_diario;
/

-- EJECUTAR SP 
BEGIN sp_generar_detalle_diario(DATE '18-08-21', 915 ); END; 



/*
CREATE OR REPLACE PROCEDURE sp_calcula_pagos (p_id_huesped NUMBER, p_valor_dolar NUMBER, p_fecha_salida DATE)
IS  
CURSOR cr_datos_huesped IS 
SELECT 
h.id_huesped, 
h.INITCAP(nom_huesped,
h.appat_huesped,
h.apmat_huesped,
a.nom_agencia, 
SUM(hab.valor_habitacion, valor_minibar) as habitacion,
tc.monto_consumos, 


FROM huesped h
LEFT JOIN agencia a 
ON h.id_agencia = a.id_agencia)
LEFT JOIN reserva r
ON h.id_huesped = r.id_huesped
LEFT JOIN detalle_reserva dr
ON r.id_reserva = dr.id_reserva
LEFT JOIN habitacion hab
ON dr.id_habitacion = hab.id_habitacion
LEFT JOIN total_consumos tc
ON h.id_huesped = tc.id_huesped
WHERE
END; 


BEGIN


END sp_calcula_pagos; 
*/










--------------------------------------------------------------------------------
--ZONA DE PRUEBAS 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PROBAR FUNCION fn_calcula_tours     //CHECKED//
--------------------------------------------------------------------------------
/*
SET SERVEROUTPUT ON; 
DECLARE 
v_total_tours NUMBER; 

BEGIN 
v_total_tours := fn_calcula_tours(340019); 
DBMS_OUTPUT.PUT_LINE(v_total_tours); 
END; 
*/

--------------------------------------------------------------------------------
-- PROBAR FUNCION  fn_retorna_agencia       // CHECKED//
--------------------------------------------------------------------------------
/*
SET SERVEROUTPUT ON 
DECLARE 
v_nom_agencia VARCHAR2(20);
BEGIN 
v_nom_agencia := fn_retorna_agencia(340646); 
DBMS_OUTPUT.PUT_LINE(v_nom_agencia); 
END; 
*/

--------------------------------------------------------------------------------
-- PROBAR FUNCION fn_consumo_dolares         // CHECKED //
--------------------------------------------------------------------------------
/*
SET SERVEROUTPUT ON 
DECLARE
v_total_consumo number; 
BEGIN 
v_total_consumo := fn_consumo_dolares(340004); 
DBMS_OUTPUT.PUT_LINE(v_total_consumo); 
END; 
*/

--------------------------------------------------------------------------------
-- PROBAR TRIGGER  trg_modificar_cargos_huesped       //  //
--------------------------------------------------------------------------------
/*SELECT
ID_HUESPED, 
MONTO_CONSUMOS 
FROM TOTAL_CONSUMOS 
WHERE ID_HUESPED = 340006; 

 
 
BEGIN 

INSERT INTO CONSUMO (ID_CONSUMO, ID_RESERVA, ID_HUESPED, MONTO)
VALUES(11527,1587,340006,150); 

DELETE FROM CONSUMO 
WHERE id_consumo = 11473; 

UPDATE CONSUMO 
SET monto =95
WHERE id_consumo = 10688; 

END;
/
*/


