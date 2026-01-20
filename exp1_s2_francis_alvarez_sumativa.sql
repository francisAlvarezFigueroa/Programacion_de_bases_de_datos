ALTER TABLE USUARIO_CLAVE
MODIFY (
    nombre_usuario VARCHAR2(20),
    clave_usuario  VARCHAR2(30)
);

--==============================================================================
--SUMATIVA EXPERIENCIA 1 : TRUCK RENTAL 
--=============================================================================

SET SERVEROUTPUT ON; 

-- TRUNCAR USUARIO_CLAVE 
TRUNCATE TABLE USUARIO_CLAVE; 

--==============================================================================
-- DECLARACION DE VARIABLES BIND PARA USAR DE PARAMETROS EN EL LOOP
--==============================================================================
VAR b_id_emp NUMBER; 
VAR b_id_min NUMBER;
VAR b_id_max NUMBER; 

EXEC :b_id_min := 100;   
EXEC :b_id_max := 320;


DECLARE
--==============================================================================
-- DECLARACION DE VARIABLES PARA USUARIO Y CLAVE 
--==============================================================================
    v_ecivil estado_civil.nombre_estado_civil%TYPE; 
    v_nombre empleado.pnombre_emp%TYPE; 
    v_snombre empleado.snombre_emp%TYPE; 
    v_symbol CHAR (1) := '*'; 
    v_sueldo_b empleado.sueldo_base%TYPE; 
    v_dv empleado.dvrun_emp%TYPE; 
    v_fecha_contrato empleado.fecha_contrato%TYPE; 
    v_nombre_usuario VARCHAR2(20);
    v_clave_usuario VARCHAR2(30); 
    v_antiguedad NUMBER; 
    v_antiguedad_exp VARCHAR2(3);
    v_run empleado.numrun_emp%TYPE; 
    v_fecha_nac empleado.fecha_nac%TYPE; 
    v_appaterno empleado.appaterno_emp%TYPE; 
    v_apmaterno empleado.apmaterno_emp%TYPE; 
    v_id_emp empleado.id_emp%TYPE; 
    v_appaterno_format VARCHAR2(2);
  
  
    v_total_empleados NUMBER;
    v_total_procesados NUMBER := 0;
    
    
    
    
BEGIN 
--==============================================================================
-- CANTIDAD DE REGISTROS A PROCESAR 
--==============================================================================
SELECT COUNT (*)
INTO v_total_empleados 
FROM empleado; 

-- INICIALIZAR VARIABLE 
:b_id_emp := :b_id_min;  

-- ENTRAR AL LOOP 

WHILE :b_id_emp <= :b_id_max LOOP

--==============================================================================
--TRAER DATOS DESDE TABLAS MEDIANTE UN SELECT
--==============================================================================
    SELECT
    eciv.nombre_estado_civil, 
    emp.pnombre_emp,
    emp.snombre_emp,
    emp.sueldo_base, 
    emp.dvrun_emp,
    emp.fecha_contrato, 
    emp.numrun_emp,
    emp.fecha_nac,
    emp.appaterno_emp,
    emp.apmaterno_emp,
    emp.id_emp
    
    
--==============================================================================
--CURSOR IMPLICITO PARA METER DATOS A VARIABLES PARA LUEGO ARMAR EL USUARIO Y CLAVE
--==============================================================================
    INTO 
    v_ecivil,
    v_nombre,
    v_snombre,
    v_sueldo_b,
    v_dv,
    v_fecha_contrato,
    v_run, 
    v_fecha_nac, 
    v_appaterno, 
    v_apmaterno, 
    v_id_emp 
    
    FROM empleado emp
    JOIN estado_civil eciv  
        ON  emp.id_estado_civil = eciv.id_estado_civiL  
    WHERE emp.id_emp = :b_id_emp; 
    
--==============================================================================
-- CALCULAR ANTIGUEDAD CONDICIONAL
--==============================================================================
   -- v_antiguedad :=  TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_contrato)/12);
    v_antiguedad :=  EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM v_fecha_contrato);

    
    IF v_antiguedad < 10 THEN 
    v_antiguedad_exp := TO_CHAR(v_antiguedad) || 'X'; -- PROFE NO EM QUEDA CLARA ESTA CONDICION
    ELSE v_antiguedad_exp := TO_CHAR(v_antiguedad);
    END IF;
    

--==============================================================================
--APLICAR FUNCIONES A VARIABLES PARA GENERAR NOMBRE_USUARIO
--==============================================================================

v_nombre_usuario :=
    LOWER(SUBSTR(v_ecivil,1,1)) ||
    UPPER(SUBSTR(v_nombre,1,3)) ||
    LENGTH(TRIM(v_nombre)) ||
    v_symbol ||
    SUBSTR(TO_CHAR(v_sueldo_b), -1) ||
    UPPER(TRIM(v_dv)) ||
    v_antiguedad_exp; 
    
    -- DBMS_OUTPUT.PUT_LINE(v_nombre_usuario);  
    
    
--==============================================================================
-- CASE V_APPATERNO 
--==============================================================================
 
 CASE
 WHEN v_ecivil IN ('CASADO', 'ACUERDO DE UNION CIVIL') THEN 
  v_appaterno_format :=
    LOWER(SUBSTR(v_appaterno,1,2));
  
 WHEN v_ecivil IN ('DIVORCIADO', 'SOLTERO') THEN 
 v_appaterno_format :=
     LOWER(SUBSTR(v_appaterno,1,1)) || UPPER(SUBSTR(v_ecivil,-1));
     
 WHEN v_ecivil = 'VIUDO' THEN 
 v_appaterno_format :=
    LOWER(SUBSTR(v_appaterno, LENGTH(v_appaterno)-2,2));
 
 WHEN v_ecivil = 'SEPARADO' THEN  
 v_appaterno_format :=
    LOWER(SUBSTR(v_appaterno,-2));
    
END CASE; 
 


--==============================================================================
--APLICAR FUNCIONES A VARIABLES PARA GENERAR CLAVE_USUARIO
--==============================================================================

v_clave_usuario:= 
    SUBSTR(TO_CHAR(v_run),3,1) ||
    TO_CHAR(EXTRACT(YEAR FROM v_fecha_nac)+2) ||
    SUBSTR(TO_CHAR((v_sueldo_b)-1),-3,3) ||
    v_appaterno_format ||
    NVL(v_id_emp,0)||
    TO_NUMBER(TO_CHAR(SYSDATE, 'DDMMYYYY'));
    
    --DBMS_OUTPUT.PUT_LINE(v_clave_usuario);  
     

    
--==============================================================================
--INSERTAR VALOTES A USUARIO_CLAVE
--==============================================================================

INSERT INTO USUARIO_CLAVE(
id_emp, 
numrun_emp, 
dvrun_emp,
nombre_empleado,
nombre_usuario, 
clave_usuario
)

VALUES(
v_id_emp,
v_run, 
v_dv,
UPPER(NVL(TRIM(
v_nombre || ' ' ||
v_snombre || ' ' ||
v_appaterno || ' ' ||
v_apmaterno
), '')), 
v_nombre_usuario, 
v_clave_usuario 

);

--==============================================================================
--  CONTADOR Y PASO DE AVANCE LOOP
--==============================================================================
v_total_procesados := v_total_procesados + 1; -- SE INCREMENTA CONTADOR
:b_id_emp := :b_id_emp + 10;       -- A QUE PASO SE INCREMENTA 

END LOOP; 

--==============================================================================
--  COMMIT / ROLLBACK
--==============================================================================

 IF v_total_procesados = v_total_empleados THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('COMMIT OK - Registros procesados: ' || v_total_procesados);
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ROLLBACK - Procesados: ' || v_total_procesados ||
                             ' / Esperados: ' || v_total_empleados);
    END IF;

END;
/


