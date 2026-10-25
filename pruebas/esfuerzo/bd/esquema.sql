-- Estructura de la base de datos del backend (solo el esquema public, sin datos), exportada de
-- producción con pg_dump el 25 oct 2026 para la prueba de esfuerzo aislada (#230).
--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: estado_pago_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_pago_enum AS ENUM (
    'pendiente',
    'aprobado',
    'rechazado',
    'reembolsado'
);


--
-- Name: estado_pedido_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_pedido_enum AS ENUM (
    'pendiente',
    'confirmado',
    'en_preparacion',
    'enviado',
    'entregado',
    'cancelado',
    'expirado'
);


--
-- Name: genero_producto_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.genero_producto_enum AS ENUM (
    'unisex',
    'dama',
    'caballero',
    'nino',
    'nina'
);


--
-- Name: rol_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.rol_enum AS ENUM (
    'cliente',
    'trabajador',
    'admin'
);


--
-- Name: tipo_descuento_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_descuento_enum AS ENUM (
    'porcentaje',
    'monto_fijo',
    'envio_gratis'
);


--
-- Name: tipo_medida_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_medida_enum AS ENUM (
    'cm',
    'mm',
    'gramos',
    'onzas',
    'talla'
);


--
-- Name: tipo_movimiento_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tipo_movimiento_enum AS ENUM (
    'entrada_compra',
    'salida_venta',
    'ajuste',
    'devolucion',
    'merma'
);


--
-- Name: actualizar_campos_producto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.actualizar_campos_producto() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    -- Obtener nombre de categoría
    SELECT nombre INTO NEW.categoria_nombre 
    FROM categorias WHERE id = NEW.categoria_id;
    
    -- Obtener nombre de proveedor
    IF NEW.proveedor_id IS NOT NULL THEN
        SELECT nombre INTO NEW.proveedor_nombre 
        FROM proveedores WHERE id = NEW.proveedor_id;
    END IF;
    
    -- Calcular precio de venta
    IF NEW.precio_compra IS NOT NULL AND NEW.margen_ganancia IS NOT NULL THEN
        NEW.precio_venta := NEW.precio_compra * (1 + NEW.margen_ganancia / 100);
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: actualizar_stock_producto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.actualizar_stock_producto() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    UPDATE productos 
    SET stock_actual = NEW.stock_nuevo,
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id = NEW.producto_id;
    RETURN NEW;
END;
$$;


--
-- Name: actualizar_total_articulos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.actualizar_total_articulos() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_venta_id INTEGER;
    v_total INTEGER;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_venta_id := OLD.venta_id;
    ELSE
        v_venta_id := NEW.venta_id;
    END IF;
    
    SELECT COALESCE(SUM(cantidad), 0) INTO v_total
    FROM detalle_ventas WHERE venta_id = v_venta_id;
    
    UPDATE ventas 
    SET total_articulos = v_total,
        fecha_actualizacion = CURRENT_TIMESTAMP
    WHERE id = v_venta_id;
    
    RETURN NULL;
END;
$$;


--
-- Name: registrar_historial_venta(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_historial_venta() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.estado != NEW.estado) THEN
        INSERT INTO historial_estado_venta (venta_id, estado_anterior, estado_nuevo, modificado_por)
        VALUES (NEW.id, OLD.estado, NEW.estado, NEW.actualizado_por);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: registrar_uso_promocion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_uso_promocion() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF NEW.promocion_id IS NOT NULL AND NEW.descuento > 0 THEN
        INSERT INTO historial_promociones (promocion_id, cliente_id, venta_id, descuento_aplicado)
        VALUES (NEW.promocion_id, NEW.cliente_id, NEW.id, NEW.descuento)
        ON CONFLICT (promocion_id, cliente_id, venta_id) DO NOTHING;
        
        UPDATE promociones 
        SET usos_actuales = usos_actuales + 1 
        WHERE id = NEW.promocion_id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: sincronizar_categoria_producto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sincronizar_categoria_producto() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.nombre != NEW.nombre) THEN
        UPDATE productos 
        SET categoria_nombre = NEW.nombre,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE categoria_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: sincronizar_login_security(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sincronizar_login_security() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    INSERT INTO login_security (user_id, email, login_attempts)
    VALUES (NEW.id, NEW.email, 0)
    ON CONFLICT (email) DO UPDATE SET user_id = NEW.id;
    RETURN NEW;
END;
$$;


--
-- Name: sincronizar_proveedor_producto(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sincronizar_proveedor_producto() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.nombre != NEW.nombre) THEN
        UPDATE productos 
        SET proveedor_nombre = NEW.nombre,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE proveedor_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: verificar_stock_productos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_stock_productos() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_stock_minimo INTEGER;
    v_nombre_producto VARCHAR(200);
BEGIN
    SELECT stock_minimo, nombre INTO v_stock_minimo, v_nombre_producto
    FROM productos WHERE id = NEW.producto_id;
    
    IF NEW.stock_nuevo <= v_stock_minimo THEN
        INSERT INTO alertas_inventario (producto_id, tipo_alerta, mensaje, nivel)
        VALUES (
            NEW.producto_id,
            CASE WHEN NEW.stock_nuevo = 0 THEN 'sin_stock' ELSE 'stock_bajo' END,
            'El producto ' || v_nombre_producto || ' tiene stock ' || 
            CASE WHEN NEW.stock_nuevo = 0 THEN 'AGOTADO' ELSE 'BAJO (' || NEW.stock_nuevo || ' unidades)' END,
            CASE WHEN NEW.stock_nuevo = 0 THEN 'critical' ELSE 'warning' END
        );
    END IF;
    
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: abonos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.abonos (
    id integer NOT NULL,
    apartado_id integer NOT NULL,
    metodo_pago_id integer NOT NULL,
    monto numeric NOT NULL,
    monto_antes numeric NOT NULL,
    monto_despues numeric NOT NULL,
    fecha_abono timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_limite_siguiente timestamp without time zone,
    estado character varying DEFAULT 'pagado'::character varying NOT NULL,
    transaccion_id integer,
    comprobante_url character varying,
    notas text,
    registrado_por integer NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT abonos_estado_check CHECK (((estado)::text = ANY ((ARRAY['pagado'::character varying, 'pendiente'::character varying, 'vencido'::character varying])::text[]))),
    CONSTRAINT abonos_monto_check CHECK ((monto > (0)::numeric))
);


--
-- Name: abonos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.abonos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: abonos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.abonos_id_seq OWNED BY public.abonos.id;


--
-- Name: alertas_inventario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alertas_inventario (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    tipo_alerta character varying(50) NOT NULL,
    mensaje text NOT NULL,
    nivel character varying(20) DEFAULT 'info'::character varying,
    resuelta boolean DEFAULT false,
    resuelta_por integer,
    fecha_resolucion timestamp without time zone,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: alertas_inventario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.alertas_inventario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: alertas_inventario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.alertas_inventario_id_seq OWNED BY public.alertas_inventario.id;


--
-- Name: apartados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apartados (
    id integer NOT NULL,
    folio character varying NOT NULL,
    venta_id integer NOT NULL,
    cliente_id integer NOT NULL,
    trabajador_id integer,
    monto_total numeric NOT NULL,
    monto_minimo_inicial numeric NOT NULL,
    monto_pagado numeric DEFAULT 0.00 NOT NULL,
    saldo_pendiente numeric NOT NULL,
    fecha_apartado timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_limite_liquidacion timestamp without time zone NOT NULL,
    fecha_liquidacion_real timestamp without time zone,
    fecha_cancelacion timestamp without time zone,
    estado character varying DEFAULT 'activo'::character varying NOT NULL,
    motivo_cancelacion text,
    cancelado_por integer,
    notas_trabajador text,
    advertencia_enviada boolean DEFAULT false,
    fecha_advertencia timestamp without time zone,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    archivado boolean DEFAULT false,
    comprobante_url text,
    plan_abono_id integer,
    fechas_abono jsonb,
    CONSTRAINT apartados_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente_pago'::character varying, 'activo'::character varying, 'liquidado'::character varying, 'cancelado'::character varying, 'vencido'::character varying])::text[])))
);


--
-- Name: apartados_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apartados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: apartados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apartados_id_seq OWNED BY public.apartados.id;


--
-- Name: atributos_personalizacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atributos_personalizacion (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo character varying(50) NOT NULL,
    opciones text,
    precio_adicional numeric(10,2) DEFAULT 0.00,
    es_requerido boolean DEFAULT false,
    activo boolean DEFAULT true
);


--
-- Name: atributos_personalizacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.atributos_personalizacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atributos_personalizacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.atributos_personalizacion_id_seq OWNED BY public.atributos_personalizacion.id;


--
-- Name: auditoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria (
    id integer NOT NULL,
    tabla character varying(100) NOT NULL,
    registro_id integer NOT NULL,
    operacion character varying(20) NOT NULL,
    usuario_id integer,
    usuario_email character varying(255),
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    ip_address character varying(45),
    user_agent text,
    fecha_operacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auditoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auditoria_id_seq OWNED BY public.auditoria.id;


--
-- Name: carrito; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carrito (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    producto_id integer NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    talla_medida character varying(100),
    nota text,
    fecha_agregado timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    solicitud_personalizacion_id integer,
    opciones jsonb,
    opciones_clave text,
    costo_opciones numeric(10,2) DEFAULT 0 NOT NULL,
    CONSTRAINT carrito_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: carrito_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carrito_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: carrito_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carrito_id_seq OWNED BY public.carrito.id;


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(300),
    categoria_padre_id integer,
    imagen_url character varying(500),
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categorias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categorias_id_seq OWNED BY public.categorias.id;


--
-- Name: clientes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clientes (
    id integer NOT NULL,
    user_id integer,
    nombre character varying(200) NOT NULL,
    apellido character varying(200),
    email character varying(255) NOT NULL,
    telefono character varying(20),
    celular character varying(20),
    fecha_nacimiento date,
    imagen_perfil character varying(500),
    notas_internas text,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: clientes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clientes_id_seq OWNED BY public.clientes.id;


--
-- Name: coleccion_productos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coleccion_productos (
    id integer NOT NULL,
    coleccion_id integer NOT NULL,
    producto_id integer NOT NULL,
    orden integer DEFAULT 0
);


--
-- Name: coleccion_productos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coleccion_productos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coleccion_productos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coleccion_productos_id_seq OWNED BY public.coleccion_productos.id;


--
-- Name: colecciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.colecciones (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text,
    imagen_url text,
    activo boolean DEFAULT true,
    orden integer DEFAULT 0,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_actualizacion timestamp without time zone DEFAULT now()
);


--
-- Name: colecciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.colecciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: colecciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.colecciones_id_seq OWNED BY public.colecciones.id;


--
-- Name: comentarios_noticias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comentarios_noticias (
    id integer NOT NULL,
    noticia_id integer NOT NULL,
    usuario_id integer NOT NULL,
    comentario text NOT NULL,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: comentarios_noticias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comentarios_noticias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comentarios_noticias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comentarios_noticias_id_seq OWNED BY public.comentarios_noticias.id;


--
-- Name: compras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.compras (
    id integer NOT NULL,
    folio character varying(50) NOT NULL,
    proveedor_id integer NOT NULL,
    proveedor_nombre character varying(200) NOT NULL,
    proveedor_contacto character varying(200),
    subtotal numeric(10,2) NOT NULL,
    iva numeric(10,2) NOT NULL,
    total numeric(10,2) NOT NULL,
    factura character varying(100),
    nota_remision character varying(100),
    notas text,
    fecha_compra date NOT NULL,
    fecha_recepcion date,
    estado character varying(50) DEFAULT 'pendiente'::character varying,
    creado_por integer NOT NULL,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: compras_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.compras_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: compras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.compras_id_seq OWNED BY public.compras.id;


--
-- Name: configuracion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configuracion (
    id integer NOT NULL,
    clave character varying(100) NOT NULL,
    valor text NOT NULL,
    tipo_dato character varying(50) NOT NULL,
    descripcion text,
    categoria character varying(100),
    es_sensible boolean DEFAULT false,
    actualizado_por integer NOT NULL,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: configuracion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.configuracion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configuracion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.configuracion_id_seq OWNED BY public.configuracion.id;


--
-- Name: configuracion_sistema; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configuracion_sistema (
    id integer NOT NULL,
    clave character varying(100) NOT NULL,
    valor text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.configuracion_sistema_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configuracion_sistema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.configuracion_sistema_id_seq OWNED BY public.configuracion_sistema.id;


--
-- Name: contenidos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contenidos (
    id integer NOT NULL,
    seccion_id integer NOT NULL,
    titulo character varying(300),
    descripcion text,
    imagen_url character varying(500),
    enlace_url character varying(500),
    enlace_nueva_ventana boolean DEFAULT false,
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    etiqueta character varying(40)
);


--
-- Name: contenidos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contenidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contenidos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contenidos_id_seq OWNED BY public.contenidos.id;


--
-- Name: cupones_clientes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cupones_clientes (
    id integer NOT NULL,
    promocion_id integer NOT NULL,
    cliente_id integer NOT NULL,
    fecha_asignacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: cupones_clientes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cupones_clientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cupones_clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cupones_clientes_id_seq OWNED BY public.cupones_clientes.id;


--
-- Name: detalle_compras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detalle_compras (
    id integer NOT NULL,
    compra_id integer NOT NULL,
    producto_id integer NOT NULL,
    producto_codigo character varying(50) NOT NULL,
    producto_nombre character varying(200) NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT detalle_compras_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: detalle_compras_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.detalle_compras_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: detalle_compras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.detalle_compras_id_seq OWNED BY public.detalle_compras.id;


--
-- Name: detalle_ventas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detalle_ventas (
    id integer NOT NULL,
    venta_id integer NOT NULL,
    producto_id integer NOT NULL,
    producto_codigo character varying(50) NOT NULL,
    producto_nombre character varying(200) NOT NULL,
    producto_imagen character varying(500),
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    descuento_unitario numeric(10,2) DEFAULT 0.00,
    personalizacion jsonb,
    subtotal numeric(10,2) NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    precio_original numeric(10,2) DEFAULT NULL::numeric,
    solicitud_personalizacion_id integer,
    CONSTRAINT detalle_ventas_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: detalle_ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.detalle_ventas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: detalle_ventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.detalle_ventas_id_seq OWNED BY public.detalle_ventas.id;


--
-- Name: direcciones_cliente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direcciones_cliente (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    alias character varying(100),
    nombre_destinatario character varying(200) NOT NULL,
    telefono_contacto character varying(20),
    calle character varying(200) NOT NULL,
    numero_exterior character varying(20),
    numero_interior character varying(20),
    colonia character varying(100) NOT NULL,
    ciudad character varying(100) NOT NULL,
    estado character varying(100) NOT NULL,
    codigo_postal character varying(10) NOT NULL,
    referencias text,
    latitud numeric(10,7),
    longitud numeric(10,7),
    es_predeterminada boolean DEFAULT false,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: direcciones_cliente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direcciones_cliente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direcciones_cliente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direcciones_cliente_id_seq OWNED BY public.direcciones_cliente.id;


--
-- Name: dispositivos_push; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispositivos_push (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token text NOT NULL,
    plataforma character varying(20) DEFAULT 'android'::character varying NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: dispositivos_push_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dispositivos_push_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dispositivos_push_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dispositivos_push_id_seq OWNED BY public.dispositivos_push.id;


--
-- Name: faqs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faqs (
    id integer NOT NULL,
    pregunta text NOT NULL,
    respuesta text NOT NULL,
    orden integer DEFAULT 0,
    activa boolean DEFAULT true,
    creado_en timestamp without time zone DEFAULT now()
);


--
-- Name: faqs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.faqs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: faqs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.faqs_id_seq OWNED BY public.faqs.id;


--
-- Name: favoritos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favoritos (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    producto_id integer NOT NULL,
    fecha_agregado timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: favoritos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.favoritos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favoritos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.favoritos_id_seq OWNED BY public.favoritos.id;


--
-- Name: historial_estado_venta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historial_estado_venta (
    id integer NOT NULL,
    venta_id integer NOT NULL,
    estado_anterior public.estado_pedido_enum,
    estado_nuevo public.estado_pedido_enum NOT NULL,
    comentario text,
    notificar_cliente boolean DEFAULT true,
    modificado_por integer,
    fecha_cambio timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: historial_estado_venta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.historial_estado_venta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historial_estado_venta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.historial_estado_venta_id_seq OWNED BY public.historial_estado_venta.id;


--
-- Name: historial_promociones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historial_promociones (
    id integer NOT NULL,
    promocion_id integer NOT NULL,
    cliente_id integer NOT NULL,
    venta_id integer,
    descuento_aplicado numeric(10,2) NOT NULL,
    fecha_uso timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: historial_promociones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.historial_promociones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historial_promociones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.historial_promociones_id_seq OWNED BY public.historial_promociones.id;


--
-- Name: imagenes_producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imagenes_producto (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    url_imagen character varying(500) NOT NULL,
    alt_texto character varying(200),
    es_principal boolean DEFAULT false,
    orden integer DEFAULT 0,
    activo boolean DEFAULT true
);


--
-- Name: imagenes_producto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.imagenes_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imagenes_producto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.imagenes_producto_id_seq OWNED BY public.imagenes_producto.id;


--
-- Name: informacion_empresa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.informacion_empresa (
    id integer DEFAULT 1 NOT NULL,
    nombre character varying(200) DEFAULT 'Joyería Diana Laura'::character varying NOT NULL,
    descripcion text,
    direccion character varying(300),
    telefono character varying(50),
    email character varying(150),
    horario text,
    mision text,
    artesania text,
    anios_tradicion integer DEFAULT 0,
    clientes_felices integer DEFAULT 0,
    facebook_url character varying(300),
    instagram_url character varying(300),
    whatsapp character varying(50),
    tiktok_url character varying(300),
    imagen_hero character varying(500),
    actualizado_por integer,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT informacion_empresa_singleton CHECK ((id = 1))
);


--
-- Name: login_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_attempts (
    id integer NOT NULL,
    user_id integer,
    email character varying(255) NOT NULL,
    ip_address character varying(45) NOT NULL,
    user_agent text,
    attempt_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    success boolean NOT NULL,
    failure_reason character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: login_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.login_attempts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.login_attempts_id_seq OWNED BY public.login_attempts.id;


--
-- Name: login_security; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_security (
    id integer NOT NULL,
    user_id integer,
    email character varying(255) NOT NULL,
    login_attempts integer DEFAULT 0,
    last_login_attempt timestamp without time zone,
    login_blocked_until timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: login_security_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.login_security_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_security_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.login_security_id_seq OWNED BY public.login_security.id;


--
-- Name: metodos_pago; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metodos_pago (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    codigo character varying(50) NOT NULL,
    descripcion text,
    tipo character varying(50) NOT NULL,
    icono_url character varying(500),
    es_pasarela boolean DEFAULT false,
    nombre_pasarela character varying(100),
    api_public_key character varying(500),
    api_secret_key_encrypted text,
    modo character varying(20) DEFAULT 'production'::character varying,
    genera_referencia_pago boolean DEFAULT false,
    comision_porcentaje numeric(5,2) DEFAULT 0.00,
    comision_fija numeric(10,2) DEFAULT 0.00,
    instrucciones_cliente text,
    instrucciones_admin text,
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: metodos_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.metodos_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metodos_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.metodos_pago_id_seq OWNED BY public.metodos_pago.id;


--
-- Name: mfa_backup_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mfa_backup_codes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    code_hash character varying(255) NOT NULL,
    usado boolean DEFAULT false,
    usado_en timestamp without time zone,
    usado_desde_ip character varying(45),
    usado_desde_dispositivo character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone DEFAULT (CURRENT_TIMESTAMP + '90 days'::interval)
);


--
-- Name: mfa_backup_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mfa_backup_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mfa_backup_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mfa_backup_codes_id_seq OWNED BY public.mfa_backup_codes.id;


--
-- Name: movimientos_inventario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.movimientos_inventario (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    tipo_movimiento public.tipo_movimiento_enum NOT NULL,
    cantidad integer NOT NULL,
    stock_anterior integer NOT NULL,
    stock_nuevo integer NOT NULL,
    costo_unitario numeric(10,2),
    costo_total numeric(10,2),
    compra_id integer,
    venta_id integer,
    proveedor character varying(200),
    numero_factura character varying(100),
    motivo text,
    observaciones text,
    realizado_por integer NOT NULL,
    fecha_movimiento timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: movimientos_inventario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.movimientos_inventario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: movimientos_inventario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.movimientos_inventario_id_seq OWNED BY public.movimientos_inventario.id;


--
-- Name: noticias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.noticias (
    id integer NOT NULL,
    titulo character varying(255) NOT NULL,
    contenido text NOT NULL,
    imagen text,
    fecha timestamp without time zone DEFAULT now(),
    activa boolean DEFAULT true
);


--
-- Name: noticias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.noticias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: noticias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.noticias_id_seq OWNED BY public.noticias.id;


--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notificaciones (
    id integer NOT NULL,
    cliente_id integer,
    venta_id integer,
    destinatario_email character varying(255),
    destinatario_telefono character varying(20),
    tipo character varying(50) NOT NULL,
    asunto character varying(200),
    mensaje text NOT NULL,
    canal character varying(20) NOT NULL,
    estado character varying(50) DEFAULT 'pendiente'::character varying,
    intentos integer DEFAULT 0,
    max_intentos integer DEFAULT 3,
    fecha_envio timestamp without time zone,
    mensaje_error text,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: notificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notificaciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notificaciones_id_seq OWNED BY public.notificaciones.id;


--
-- Name: oauth_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_codes (
    id integer NOT NULL,
    code character varying(255) NOT NULL,
    usuario_id integer NOT NULL,
    redirect_uri text NOT NULL,
    client_id character varying(255) NOT NULL,
    usado boolean DEFAULT false,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_expira timestamp without time zone NOT NULL
);


--
-- Name: oauth_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_codes_id_seq OWNED BY public.oauth_codes.id;


--
-- Name: oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_tokens (
    id integer NOT NULL,
    access_token character varying(255) NOT NULL,
    refresh_token character varying(255) NOT NULL,
    usuario_id integer NOT NULL,
    client_id character varying(255) NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_expira timestamp without time zone NOT NULL,
    revocado boolean DEFAULT false
);


--
-- Name: oauth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_tokens_id_seq OWNED BY public.oauth_tokens.id;


--
-- Name: page_content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_content (
    id integer NOT NULL,
    page_name character varying(100) NOT NULL,
    titulo text,
    contenido text,
    imagen text DEFAULT ''::text,
    fecha timestamp with time zone DEFAULT now()
);


--
-- Name: page_content_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.page_content_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: page_content_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.page_content_id_seq OWNED BY public.page_content.id;


--
-- Name: paginas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paginas (
    id integer NOT NULL,
    nombre character varying(200) NOT NULL,
    slug character varying(200) NOT NULL,
    descripcion text,
    icono character varying(100),
    orden integer DEFAULT 0,
    mostrar_en_menu boolean DEFAULT true,
    mostrar_en_footer boolean DEFAULT false,
    requiere_autenticacion boolean DEFAULT false,
    activo boolean DEFAULT true,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: paginas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.paginas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: paginas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.paginas_id_seq OWNED BY public.paginas.id;


--
-- Name: personalizacion_grupos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personalizacion_grupos (
    id integer NOT NULL,
    categoria_id integer,
    producto_id integer,
    nombre character varying(60) NOT NULL,
    requerido boolean DEFAULT false NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT personalizacion_grupos_destino CHECK (((categoria_id IS NULL) <> (producto_id IS NULL)))
);


--
-- Name: personalizacion_grupos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personalizacion_grupos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personalizacion_grupos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personalizacion_grupos_id_seq OWNED BY public.personalizacion_grupos.id;


--
-- Name: personalizacion_opciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personalizacion_opciones (
    id integer NOT NULL,
    grupo_id integer NOT NULL,
    etiqueta character varying(60) NOT NULL,
    costo_extra numeric(10,2) DEFAULT 0 NOT NULL,
    pide_texto boolean DEFAULT false NOT NULL,
    texto_ayuda character varying(80),
    orden integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT personalizacion_opciones_costo_extra_check CHECK ((costo_extra >= (0)::numeric))
);


--
-- Name: personalizacion_opciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personalizacion_opciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personalizacion_opciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personalizacion_opciones_id_seq OWNED BY public.personalizacion_opciones.id;


--
-- Name: planes_abono; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planes_abono (
    id integer NOT NULL,
    nombre character varying NOT NULL,
    intervalo_dias integer NOT NULL,
    porcentaje_abono numeric NOT NULL,
    descripcion text,
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT planes_abono_intervalo_dias_check CHECK ((intervalo_dias > 0)),
    CONSTRAINT planes_abono_porcentaje_abono_check CHECK (((porcentaje_abono > (0)::numeric) AND (porcentaje_abono <= (100)::numeric)))
);


--
-- Name: planes_abono_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.planes_abono_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: planes_abono_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.planes_abono_id_seq OWNED BY public.planes_abono.id;


--
-- Name: plantillas_notificacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plantillas_notificacion (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    asunto character varying(200) NOT NULL,
    cuerpo text NOT NULL,
    variables_disponibles text,
    canal character varying(20) NOT NULL,
    activo boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: plantillas_notificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plantillas_notificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plantillas_notificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plantillas_notificacion_id_seq OWNED BY public.plantillas_notificacion.id;


--
-- Name: preguntas_frecuentes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.preguntas_frecuentes (
    id integer NOT NULL,
    categoria character varying(100),
    pregunta text NOT NULL,
    respuesta text NOT NULL,
    orden integer DEFAULT 0,
    contador_util integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: preguntas_frecuentes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.preguntas_frecuentes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: preguntas_frecuentes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.preguntas_frecuentes_id_seq OWNED BY public.preguntas_frecuentes.id;


--
-- Name: productos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.productos (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    categoria_id integer NOT NULL,
    proveedor_id integer,
    temporada_id integer,
    tipo_producto_id integer,
    categoria_nombre character varying(100),
    proveedor_nombre character varying(100),
    genero public.genero_producto_enum DEFAULT 'unisex'::public.genero_producto_enum,
    material_principal character varying(100),
    materiales_detalle jsonb,
    peso_gramos numeric(10,3),
    precio_compra numeric(10,2),
    margen_ganancia numeric(5,2),
    precio_venta numeric(10,2),
    precio_oferta numeric(10,2),
    stock_actual integer DEFAULT 0,
    stock_minimo integer DEFAULT 5,
    stock_maximo integer DEFAULT 999,
    ubicacion_fisica character varying(100),
    tiene_medidas boolean DEFAULT false,
    medidas jsonb,
    permite_personalizacion boolean DEFAULT false,
    imagen_principal character varying(500),
    es_nuevo boolean DEFAULT false,
    es_destacado boolean DEFAULT false,
    activo boolean DEFAULT true,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    precio_personalizacion numeric(10,2) DEFAULT 0 NOT NULL,
    ubicaciones_entrega jsonb DEFAULT '[]'::jsonb
);


--
-- Name: productos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.productos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: productos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.productos_id_seq OWNED BY public.productos.id;


--
-- Name: promociones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promociones (
    id integer NOT NULL,
    nombre character varying(200) NOT NULL,
    codigo_cupon character varying(50),
    descripcion text,
    tipo public.tipo_descuento_enum NOT NULL,
    valor_descuento numeric(10,2) NOT NULL,
    aplica_categorias integer[],
    aplica_proveedores integer[],
    aplica_temporadas integer[],
    aplica_productos integer[],
    aplica_genero public.genero_producto_enum,
    aplica_tipos_producto integer[],
    monto_minimo_compra numeric(10,2),
    cantidad_minima_productos integer,
    limite_usos_total integer,
    usos_actuales integer DEFAULT 0,
    limite_usos_por_cliente integer DEFAULT 1,
    fecha_inicio timestamp without time zone NOT NULL,
    fecha_fin timestamp without time zone NOT NULL,
    activo boolean DEFAULT true,
    creado_por integer NOT NULL,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: promociones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.promociones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: promociones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.promociones_id_seq OWNED BY public.promociones.id;


--
-- Name: proveedores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proveedores (
    id integer NOT NULL,
    nombre character varying(200) NOT NULL,
    razon_social character varying(300),
    rfc character varying(20),
    direccion text,
    telefono character varying(20),
    email character varying(255),
    sitio_web character varying(300),
    persona_contacto character varying(200),
    notas text,
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_por integer,
    imagen_url text
);


--
-- Name: proveedores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.proveedores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proveedores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.proveedores_id_seq OWNED BY public.proveedores.id;


--
-- Name: request_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_logs (
    id bigint NOT NULL,
    method character varying(10) NOT NULL,
    endpoint character varying(500) NOT NULL,
    status_code integer NOT NULL,
    duration_ms integer NOT NULL,
    user_id integer,
    ip_address character varying(50),
    user_agent text,
    error_message text,
    memoria_mb numeric(8,2),
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: request_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.request_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: request_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.request_logs_id_seq OWNED BY public.request_logs.id;


--
-- Name: resenas_producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resenas_producto (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    usuario_id integer NOT NULL,
    cliente_nombre character varying(150) NOT NULL,
    calificacion integer NOT NULL,
    comentario text,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT resenas_producto_calificacion_check CHECK (((calificacion >= 1) AND (calificacion <= 5)))
);


--
-- Name: resenas_producto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resenas_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resenas_producto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resenas_producto_id_seq OWNED BY public.resenas_producto.id;


--
-- Name: respaldos_historial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.respaldos_historial (
    id integer NOT NULL,
    nombre_archivo character varying(255) NOT NULL,
    tipo character varying(50) DEFAULT 'manual'::character varying,
    tamano character varying(50),
    estado character varying(20) DEFAULT 'completado'::character varying,
    usuario_id integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    detalles_log text,
    url_archivo character varying
);


--
-- Name: respaldos_historial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.respaldos_historial_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: respaldos_historial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.respaldos_historial_id_seq OWNED BY public.respaldos_historial.id;


--
-- Name: secciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secciones (
    id integer NOT NULL,
    pagina_id integer NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    imagen_url character varying(500),
    color_fondo character varying(20),
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: secciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.secciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: secciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.secciones_id_seq OWNED BY public.secciones.id;


--
-- Name: security_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_questions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    question_text character varying(500) NOT NULL,
    answer_hash character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: security_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_questions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.security_questions_id_seq OWNED BY public.security_questions.id;


--
-- Name: solicitudes_cambio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes_cambio (
    id integer NOT NULL,
    usuario_id integer,
    campo character varying(50) NOT NULL,
    valor_nuevo character varying(255) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    creado_en timestamp without time zone DEFAULT now(),
    revisado_en timestamp without time zone,
    revisado_por integer
);


--
-- Name: solicitudes_cambio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solicitudes_cambio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solicitudes_cambio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solicitudes_cambio_id_seq OWNED BY public.solicitudes_cambio.id;


--
-- Name: solicitudes_personalizacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitudes_personalizacion (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    producto_id integer NOT NULL,
    detalle text NOT NULL,
    imagen_referencia_url text,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    motivo_rechazo text,
    utilizada boolean DEFAULT false NOT NULL,
    respondido_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_respuesta timestamp without time zone,
    CONSTRAINT solicitudes_personalizacion_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'aprobada'::character varying, 'rechazada'::character varying])::text[])))
);


--
-- Name: solicitudes_personalizacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solicitudes_personalizacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solicitudes_personalizacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solicitudes_personalizacion_id_seq OWNED BY public.solicitudes_personalizacion.id;


--
-- Name: system_errors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_errors (
    id bigint NOT NULL,
    tipo character varying(100) NOT NULL,
    mensaje text NOT NULL,
    stack_trace text,
    endpoint character varying(500),
    method character varying(10),
    user_id integer,
    ip_address character varying(50),
    resuelta boolean DEFAULT false,
    resuelta_por integer,
    fecha_resolucion timestamp without time zone,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: system_errors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_errors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_errors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.system_errors_id_seq OWNED BY public.system_errors.id;


--
-- Name: temas_temporada; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.temas_temporada (
    id integer NOT NULL,
    clave character varying(40) NOT NULL,
    nombre character varying(60) NOT NULL,
    descripcion character varying(160),
    modo character varying(10) DEFAULT 'oscuro'::character varying NOT NULL,
    color_fondo character varying(9) NOT NULL,
    color_superficie character varying(9) NOT NULL,
    color_superficie_2 character varying(9) NOT NULL,
    color_principal character varying(9) NOT NULL,
    color_principal_fuerte character varying(9) NOT NULL,
    color_acento character varying(9) NOT NULL,
    color_texto character varying(9) NOT NULL,
    color_texto_suave character varying(9) NOT NULL,
    decoracion character varying(20) DEFAULT 'ninguna'::character varying NOT NULL,
    activo boolean DEFAULT false NOT NULL,
    fecha_inicio date,
    fecha_fin date,
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT temas_temporada_decoracion_check CHECK (((decoracion)::text = ANY ((ARRAY['ninguna'::character varying, 'calabazas'::character varying, 'corazones'::character varying, 'nieve'::character varying, 'estrellas'::character varying, 'flores'::character varying])::text[]))),
    CONSTRAINT temas_temporada_modo_check CHECK (((modo)::text = ANY ((ARRAY['oscuro'::character varying, 'claro'::character varying])::text[])))
);


--
-- Name: temas_temporada_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.temas_temporada_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: temas_temporada_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.temas_temporada_id_seq OWNED BY public.temas_temporada.id;


--
-- Name: temporadas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.temporadas (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    imagen_url character varying(500),
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: temporadas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.temporadas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: temporadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.temporadas_id_seq OWNED BY public.temporadas.id;


--
-- Name: tipos_producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_producto (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(300),
    activo boolean DEFAULT true,
    creado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: tipos_producto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipos_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipos_producto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_producto_id_seq OWNED BY public.tipos_producto.id;


--
-- Name: transacciones_pago; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transacciones_pago (
    id integer NOT NULL,
    venta_id integer NOT NULL,
    metodo_pago_id integer NOT NULL,
    transaction_id character varying(200),
    referencia_pago character varying(200),
    payment_intent_id character varying(200),
    monto numeric(10,2) NOT NULL,
    moneda character varying(3) DEFAULT 'MXN'::character varying,
    comision numeric(10,2) DEFAULT 0.00,
    monto_neto numeric(10,2) NOT NULL,
    estado public.estado_pago_enum DEFAULT 'pendiente'::public.estado_pago_enum,
    estado_pasarela character varying(50),
    metodo_especifico character varying(50),
    ultimos_4_digitos character varying(4),
    banco character varying(100),
    nombre_titular character varying(200),
    fecha_expiracion_referencia timestamp without time zone,
    fecha_procesamiento timestamp without time zone,
    fecha_aprobacion timestamp without time zone,
    fecha_reembolso timestamp without time zone,
    respuesta_completa jsonb,
    mensaje_error text,
    codigo_error character varying(100),
    ip_cliente character varying(45),
    user_agent text,
    procesado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: transacciones_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transacciones_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transacciones_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transacciones_pago_id_seq OWNED BY public.transacciones_pago.id;


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    session_token character varying(500) NOT NULL,
    device_fingerprint character varying(16),
    firebase_uid character varying(255),
    device_name character varying(255),
    browser character varying(100),
    os character varying(100),
    ip_address character varying(45),
    user_agent text,
    location character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_activity timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone NOT NULL,
    is_revoked boolean DEFAULT false,
    revoked_at timestamp without time zone
);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id integer NOT NULL,
    firebase_uid character varying(128) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    nombre character varying(100),
    rol public.rol_enum DEFAULT 'cliente'::public.rol_enum,
    activo boolean DEFAULT true,
    mfa_enabled boolean DEFAULT false,
    mfa_secret character varying(100),
    mfa_backup_codes text[],
    mfa_verified boolean DEFAULT false,
    mfa_setup_token character varying(255),
    mfa_setup_token_expires timestamp without time zone,
    reset_password_token character varying(255),
    reset_password_expires timestamp without time zone,
    recovery_attempts integer DEFAULT 0,
    last_recovery_attempt timestamp without time zone,
    recovery_blocked_until timestamp without time zone,
    last_activity timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    telefono character varying(20),
    activado boolean DEFAULT true,
    codigo_activacion_hash character varying(255),
    codigo_trabajador character varying(20),
    foto_perfil_url text
);


--
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;


--
-- Name: ventas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ventas (
    id integer NOT NULL,
    folio character varying(50) NOT NULL,
    cliente_id integer NOT NULL,
    direccion_entrega_id integer,
    metodo_pago_id integer NOT NULL,
    promocion_id integer,
    estado public.estado_pedido_enum DEFAULT 'pendiente'::public.estado_pedido_enum,
    cliente_nombre_completo character varying(400) NOT NULL,
    cliente_email character varying(255) NOT NULL,
    cliente_telefono character varying(20),
    total_articulos integer DEFAULT 0,
    subtotal numeric(10,2) NOT NULL,
    descuento numeric(10,2) DEFAULT 0.00,
    iva numeric(10,2) NOT NULL,
    costo_envio numeric(10,2) DEFAULT 0.00,
    total numeric(10,2) NOT NULL,
    notas_cliente text,
    notas_internas text,
    numero_guia character varying(100),
    paqueteria character varying(100),
    fecha_estimada_entrega date,
    fecha_cancelacion timestamp without time zone,
    cancelado_por integer,
    motivo_cancelacion text,
    creado_por integer,
    actualizado_por integer,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    trabajador_id integer,
    comprobante_transferencia_url text,
    codigo_entrega character varying(8),
    codigo_entrega_usado boolean DEFAULT false,
    tipo_entrega character varying(20) DEFAULT 'tienda'::character varying,
    fecha_limite_pago timestamp without time zone
);


--
-- Name: ventas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ventas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ventas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ventas_id_seq OWNED BY public.ventas.id;


--
-- Name: visitas_sitio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visitas_sitio (
    id integer NOT NULL,
    visitor_id character varying(64) NOT NULL,
    ruta character varying(255),
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: visitas_sitio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visitas_sitio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visitas_sitio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visitas_sitio_id_seq OWNED BY public.visitas_sitio.id;


--
-- Name: webhooks_pasarela; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhooks_pasarela (
    id integer NOT NULL,
    metodo_pago_id integer,
    transaction_id character varying(200),
    tipo_evento character varying(100) NOT NULL,
    payload_completo jsonb NOT NULL,
    headers jsonb,
    procesado boolean DEFAULT false,
    procesado_por integer,
    fecha_procesamiento timestamp without time zone,
    ip_origen character varying(45),
    fecha_recepcion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: webhooks_pasarela_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhooks_pasarela_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhooks_pasarela_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhooks_pasarela_id_seq OWNED BY public.webhooks_pasarela.id;


--
-- Name: zonas_entrega; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zonas_entrega (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    activo boolean DEFAULT true,
    orden integer DEFAULT 0,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: zonas_entrega_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zonas_entrega_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zonas_entrega_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zonas_entrega_id_seq OWNED BY public.zonas_entrega.id;


--
-- Name: abonos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos ALTER COLUMN id SET DEFAULT nextval('public.abonos_id_seq'::regclass);


--
-- Name: alertas_inventario id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alertas_inventario ALTER COLUMN id SET DEFAULT nextval('public.alertas_inventario_id_seq'::regclass);


--
-- Name: apartados id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados ALTER COLUMN id SET DEFAULT nextval('public.apartados_id_seq'::regclass);


--
-- Name: atributos_personalizacion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atributos_personalizacion ALTER COLUMN id SET DEFAULT nextval('public.atributos_personalizacion_id_seq'::regclass);


--
-- Name: auditoria id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria ALTER COLUMN id SET DEFAULT nextval('public.auditoria_id_seq'::regclass);


--
-- Name: carrito id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito ALTER COLUMN id SET DEFAULT nextval('public.carrito_id_seq'::regclass);


--
-- Name: categorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias ALTER COLUMN id SET DEFAULT nextval('public.categorias_id_seq'::regclass);


--
-- Name: clientes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes ALTER COLUMN id SET DEFAULT nextval('public.clientes_id_seq'::regclass);


--
-- Name: coleccion_productos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coleccion_productos ALTER COLUMN id SET DEFAULT nextval('public.coleccion_productos_id_seq'::regclass);


--
-- Name: colecciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colecciones ALTER COLUMN id SET DEFAULT nextval('public.colecciones_id_seq'::regclass);


--
-- Name: comentarios_noticias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios_noticias ALTER COLUMN id SET DEFAULT nextval('public.comentarios_noticias_id_seq'::regclass);


--
-- Name: compras id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras ALTER COLUMN id SET DEFAULT nextval('public.compras_id_seq'::regclass);


--
-- Name: configuracion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion ALTER COLUMN id SET DEFAULT nextval('public.configuracion_id_seq'::regclass);


--
-- Name: configuracion_sistema id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion_sistema ALTER COLUMN id SET DEFAULT nextval('public.configuracion_sistema_id_seq'::regclass);


--
-- Name: contenidos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contenidos ALTER COLUMN id SET DEFAULT nextval('public.contenidos_id_seq'::regclass);


--
-- Name: cupones_clientes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cupones_clientes ALTER COLUMN id SET DEFAULT nextval('public.cupones_clientes_id_seq'::regclass);


--
-- Name: detalle_compras id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_compras ALTER COLUMN id SET DEFAULT nextval('public.detalle_compras_id_seq'::regclass);


--
-- Name: detalle_ventas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_ventas ALTER COLUMN id SET DEFAULT nextval('public.detalle_ventas_id_seq'::regclass);


--
-- Name: direcciones_cliente id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direcciones_cliente ALTER COLUMN id SET DEFAULT nextval('public.direcciones_cliente_id_seq'::regclass);


--
-- Name: dispositivos_push id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos_push ALTER COLUMN id SET DEFAULT nextval('public.dispositivos_push_id_seq'::regclass);


--
-- Name: faqs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faqs ALTER COLUMN id SET DEFAULT nextval('public.faqs_id_seq'::regclass);


--
-- Name: favoritos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favoritos ALTER COLUMN id SET DEFAULT nextval('public.favoritos_id_seq'::regclass);


--
-- Name: historial_estado_venta id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_estado_venta ALTER COLUMN id SET DEFAULT nextval('public.historial_estado_venta_id_seq'::regclass);


--
-- Name: historial_promociones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones ALTER COLUMN id SET DEFAULT nextval('public.historial_promociones_id_seq'::regclass);


--
-- Name: imagenes_producto id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagenes_producto ALTER COLUMN id SET DEFAULT nextval('public.imagenes_producto_id_seq'::regclass);


--
-- Name: login_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_attempts ALTER COLUMN id SET DEFAULT nextval('public.login_attempts_id_seq'::regclass);


--
-- Name: login_security id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_security ALTER COLUMN id SET DEFAULT nextval('public.login_security_id_seq'::regclass);


--
-- Name: metodos_pago id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodos_pago ALTER COLUMN id SET DEFAULT nextval('public.metodos_pago_id_seq'::regclass);


--
-- Name: mfa_backup_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mfa_backup_codes ALTER COLUMN id SET DEFAULT nextval('public.mfa_backup_codes_id_seq'::regclass);


--
-- Name: movimientos_inventario id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario ALTER COLUMN id SET DEFAULT nextval('public.movimientos_inventario_id_seq'::regclass);


--
-- Name: noticias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticias ALTER COLUMN id SET DEFAULT nextval('public.noticias_id_seq'::regclass);


--
-- Name: notificaciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones ALTER COLUMN id SET DEFAULT nextval('public.notificaciones_id_seq'::regclass);


--
-- Name: oauth_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes ALTER COLUMN id SET DEFAULT nextval('public.oauth_codes_id_seq'::regclass);


--
-- Name: oauth_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_tokens_id_seq'::regclass);


--
-- Name: page_content id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_content ALTER COLUMN id SET DEFAULT nextval('public.page_content_id_seq'::regclass);


--
-- Name: paginas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paginas ALTER COLUMN id SET DEFAULT nextval('public.paginas_id_seq'::regclass);


--
-- Name: personalizacion_grupos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_grupos ALTER COLUMN id SET DEFAULT nextval('public.personalizacion_grupos_id_seq'::regclass);


--
-- Name: personalizacion_opciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_opciones ALTER COLUMN id SET DEFAULT nextval('public.personalizacion_opciones_id_seq'::regclass);


--
-- Name: planes_abono id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_abono ALTER COLUMN id SET DEFAULT nextval('public.planes_abono_id_seq'::regclass);


--
-- Name: plantillas_notificacion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plantillas_notificacion ALTER COLUMN id SET DEFAULT nextval('public.plantillas_notificacion_id_seq'::regclass);


--
-- Name: preguntas_frecuentes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preguntas_frecuentes ALTER COLUMN id SET DEFAULT nextval('public.preguntas_frecuentes_id_seq'::regclass);


--
-- Name: productos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos ALTER COLUMN id SET DEFAULT nextval('public.productos_id_seq'::regclass);


--
-- Name: promociones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones ALTER COLUMN id SET DEFAULT nextval('public.promociones_id_seq'::regclass);


--
-- Name: proveedores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores ALTER COLUMN id SET DEFAULT nextval('public.proveedores_id_seq'::regclass);


--
-- Name: request_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_logs ALTER COLUMN id SET DEFAULT nextval('public.request_logs_id_seq'::regclass);


--
-- Name: resenas_producto id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resenas_producto ALTER COLUMN id SET DEFAULT nextval('public.resenas_producto_id_seq'::regclass);


--
-- Name: respaldos_historial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.respaldos_historial ALTER COLUMN id SET DEFAULT nextval('public.respaldos_historial_id_seq'::regclass);


--
-- Name: secciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secciones ALTER COLUMN id SET DEFAULT nextval('public.secciones_id_seq'::regclass);


--
-- Name: security_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_questions ALTER COLUMN id SET DEFAULT nextval('public.security_questions_id_seq'::regclass);


--
-- Name: solicitudes_cambio id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_cambio ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_cambio_id_seq'::regclass);


--
-- Name: solicitudes_personalizacion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_personalizacion ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_personalizacion_id_seq'::regclass);


--
-- Name: system_errors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_errors ALTER COLUMN id SET DEFAULT nextval('public.system_errors_id_seq'::regclass);


--
-- Name: temas_temporada id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temas_temporada ALTER COLUMN id SET DEFAULT nextval('public.temas_temporada_id_seq'::regclass);


--
-- Name: temporadas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temporadas ALTER COLUMN id SET DEFAULT nextval('public.temporadas_id_seq'::regclass);


--
-- Name: tipos_producto id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_producto ALTER COLUMN id SET DEFAULT nextval('public.tipos_producto_id_seq'::regclass);


--
-- Name: transacciones_pago id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago ALTER COLUMN id SET DEFAULT nextval('public.transacciones_pago_id_seq'::regclass);


--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);


--
-- Name: usuarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- Name: ventas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas ALTER COLUMN id SET DEFAULT nextval('public.ventas_id_seq'::regclass);


--
-- Name: visitas_sitio id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitas_sitio ALTER COLUMN id SET DEFAULT nextval('public.visitas_sitio_id_seq'::regclass);


--
-- Name: webhooks_pasarela id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks_pasarela ALTER COLUMN id SET DEFAULT nextval('public.webhooks_pasarela_id_seq'::regclass);


--
-- Name: zonas_entrega id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas_entrega ALTER COLUMN id SET DEFAULT nextval('public.zonas_entrega_id_seq'::regclass);


--
-- Name: abonos abonos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos
    ADD CONSTRAINT abonos_pkey PRIMARY KEY (id);


--
-- Name: alertas_inventario alertas_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alertas_inventario
    ADD CONSTRAINT alertas_inventario_pkey PRIMARY KEY (id);


--
-- Name: apartados apartados_folio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT apartados_folio_key UNIQUE (folio);


--
-- Name: apartados apartados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT apartados_pkey PRIMARY KEY (id);


--
-- Name: atributos_personalizacion atributos_personalizacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atributos_personalizacion
    ADD CONSTRAINT atributos_personalizacion_pkey PRIMARY KEY (id);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);


--
-- Name: carrito carrito_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito
    ADD CONSTRAINT carrito_pkey PRIMARY KEY (id);


--
-- Name: carrito carrito_usuario_id_producto_id_talla_medida_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito
    ADD CONSTRAINT carrito_usuario_id_producto_id_talla_medida_key UNIQUE (usuario_id, producto_id, talla_medida);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);


--
-- Name: coleccion_productos coleccion_productos_coleccion_id_producto_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coleccion_productos
    ADD CONSTRAINT coleccion_productos_coleccion_id_producto_id_key UNIQUE (coleccion_id, producto_id);


--
-- Name: coleccion_productos coleccion_productos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coleccion_productos
    ADD CONSTRAINT coleccion_productos_pkey PRIMARY KEY (id);


--
-- Name: colecciones colecciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colecciones
    ADD CONSTRAINT colecciones_pkey PRIMARY KEY (id);


--
-- Name: comentarios_noticias comentarios_noticias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios_noticias
    ADD CONSTRAINT comentarios_noticias_pkey PRIMARY KEY (id);


--
-- Name: compras compras_folio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT compras_folio_key UNIQUE (folio);


--
-- Name: compras compras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT compras_pkey PRIMARY KEY (id);


--
-- Name: configuracion configuracion_clave_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion
    ADD CONSTRAINT configuracion_clave_key UNIQUE (clave);


--
-- Name: configuracion configuracion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion
    ADD CONSTRAINT configuracion_pkey PRIMARY KEY (id);


--
-- Name: configuracion_sistema configuracion_sistema_clave_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_clave_key UNIQUE (clave);


--
-- Name: configuracion_sistema configuracion_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_pkey PRIMARY KEY (id);


--
-- Name: contenidos contenidos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contenidos
    ADD CONSTRAINT contenidos_pkey PRIMARY KEY (id);


--
-- Name: cupones_clientes cupones_clientes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cupones_clientes
    ADD CONSTRAINT cupones_clientes_pkey PRIMARY KEY (id);


--
-- Name: cupones_clientes cupones_clientes_promocion_id_cliente_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cupones_clientes
    ADD CONSTRAINT cupones_clientes_promocion_id_cliente_id_key UNIQUE (promocion_id, cliente_id);


--
-- Name: detalle_compras detalle_compras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_compras
    ADD CONSTRAINT detalle_compras_pkey PRIMARY KEY (id);


--
-- Name: detalle_ventas detalle_ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_ventas
    ADD CONSTRAINT detalle_ventas_pkey PRIMARY KEY (id);


--
-- Name: direcciones_cliente direcciones_cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direcciones_cliente
    ADD CONSTRAINT direcciones_cliente_pkey PRIMARY KEY (id);


--
-- Name: dispositivos_push dispositivos_push_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos_push
    ADD CONSTRAINT dispositivos_push_pkey PRIMARY KEY (id);


--
-- Name: dispositivos_push dispositivos_push_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos_push
    ADD CONSTRAINT dispositivos_push_token_key UNIQUE (token);


--
-- Name: faqs faqs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faqs
    ADD CONSTRAINT faqs_pkey PRIMARY KEY (id);


--
-- Name: favoritos favoritos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_pkey PRIMARY KEY (id);


--
-- Name: favoritos favoritos_usuario_id_producto_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_usuario_id_producto_id_key UNIQUE (usuario_id, producto_id);


--
-- Name: historial_estado_venta historial_estado_venta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_estado_venta
    ADD CONSTRAINT historial_estado_venta_pkey PRIMARY KEY (id);


--
-- Name: historial_promociones historial_promociones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones
    ADD CONSTRAINT historial_promociones_pkey PRIMARY KEY (id);


--
-- Name: historial_promociones historial_promociones_promocion_id_cliente_id_venta_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones
    ADD CONSTRAINT historial_promociones_promocion_id_cliente_id_venta_id_key UNIQUE (promocion_id, cliente_id, venta_id);


--
-- Name: imagenes_producto imagenes_producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagenes_producto
    ADD CONSTRAINT imagenes_producto_pkey PRIMARY KEY (id);


--
-- Name: informacion_empresa informacion_empresa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informacion_empresa
    ADD CONSTRAINT informacion_empresa_pkey PRIMARY KEY (id);


--
-- Name: login_attempts login_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_attempts
    ADD CONSTRAINT login_attempts_pkey PRIMARY KEY (id);


--
-- Name: login_security login_security_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_security
    ADD CONSTRAINT login_security_email_key UNIQUE (email);


--
-- Name: login_security login_security_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_security
    ADD CONSTRAINT login_security_pkey PRIMARY KEY (id);


--
-- Name: metodos_pago metodos_pago_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodos_pago
    ADD CONSTRAINT metodos_pago_codigo_key UNIQUE (codigo);


--
-- Name: metodos_pago metodos_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodos_pago
    ADD CONSTRAINT metodos_pago_pkey PRIMARY KEY (id);


--
-- Name: mfa_backup_codes mfa_backup_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mfa_backup_codes
    ADD CONSTRAINT mfa_backup_codes_pkey PRIMARY KEY (id);


--
-- Name: movimientos_inventario movimientos_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT movimientos_inventario_pkey PRIMARY KEY (id);


--
-- Name: noticias noticias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticias
    ADD CONSTRAINT noticias_pkey PRIMARY KEY (id);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);


--
-- Name: oauth_codes oauth_codes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_code_key UNIQUE (code);


--
-- Name: oauth_codes oauth_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_pkey PRIMARY KEY (id);


--
-- Name: oauth_tokens oauth_tokens_access_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_access_token_key UNIQUE (access_token);


--
-- Name: oauth_tokens oauth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_tokens oauth_tokens_refresh_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_refresh_token_key UNIQUE (refresh_token);


--
-- Name: page_content page_content_page_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_content
    ADD CONSTRAINT page_content_page_name_key UNIQUE (page_name);


--
-- Name: page_content page_content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_content
    ADD CONSTRAINT page_content_pkey PRIMARY KEY (id);


--
-- Name: paginas paginas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paginas
    ADD CONSTRAINT paginas_pkey PRIMARY KEY (id);


--
-- Name: paginas paginas_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paginas
    ADD CONSTRAINT paginas_slug_key UNIQUE (slug);


--
-- Name: personalizacion_grupos personalizacion_grupos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_grupos
    ADD CONSTRAINT personalizacion_grupos_pkey PRIMARY KEY (id);


--
-- Name: personalizacion_opciones personalizacion_opciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_opciones
    ADD CONSTRAINT personalizacion_opciones_pkey PRIMARY KEY (id);


--
-- Name: planes_abono planes_abono_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_abono
    ADD CONSTRAINT planes_abono_pkey PRIMARY KEY (id);


--
-- Name: plantillas_notificacion plantillas_notificacion_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plantillas_notificacion
    ADD CONSTRAINT plantillas_notificacion_codigo_key UNIQUE (codigo);


--
-- Name: plantillas_notificacion plantillas_notificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plantillas_notificacion
    ADD CONSTRAINT plantillas_notificacion_pkey PRIMARY KEY (id);


--
-- Name: preguntas_frecuentes preguntas_frecuentes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preguntas_frecuentes
    ADD CONSTRAINT preguntas_frecuentes_pkey PRIMARY KEY (id);


--
-- Name: productos productos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_codigo_key UNIQUE (codigo);


--
-- Name: productos productos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id);


--
-- Name: promociones promociones_codigo_cupon_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT promociones_codigo_cupon_key UNIQUE (codigo_cupon);


--
-- Name: promociones promociones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT promociones_pkey PRIMARY KEY (id);


--
-- Name: proveedores proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);


--
-- Name: request_logs request_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_logs
    ADD CONSTRAINT request_logs_pkey PRIMARY KEY (id);


--
-- Name: resenas_producto resenas_producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resenas_producto
    ADD CONSTRAINT resenas_producto_pkey PRIMARY KEY (id);


--
-- Name: resenas_producto resenas_producto_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resenas_producto
    ADD CONSTRAINT resenas_producto_unico UNIQUE (producto_id, usuario_id);


--
-- Name: respaldos_historial respaldos_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.respaldos_historial
    ADD CONSTRAINT respaldos_historial_pkey PRIMARY KEY (id);


--
-- Name: secciones secciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secciones
    ADD CONSTRAINT secciones_pkey PRIMARY KEY (id);


--
-- Name: security_questions security_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_questions
    ADD CONSTRAINT security_questions_pkey PRIMARY KEY (id);


--
-- Name: security_questions security_questions_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_questions
    ADD CONSTRAINT security_questions_user_id_key UNIQUE (user_id);


--
-- Name: solicitudes_cambio solicitudes_cambio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_cambio
    ADD CONSTRAINT solicitudes_cambio_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_personalizacion solicitudes_personalizacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_personalizacion
    ADD CONSTRAINT solicitudes_personalizacion_pkey PRIMARY KEY (id);


--
-- Name: system_errors system_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_errors
    ADD CONSTRAINT system_errors_pkey PRIMARY KEY (id);


--
-- Name: temas_temporada temas_temporada_clave_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temas_temporada
    ADD CONSTRAINT temas_temporada_clave_key UNIQUE (clave);


--
-- Name: temas_temporada temas_temporada_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temas_temporada
    ADD CONSTRAINT temas_temporada_pkey PRIMARY KEY (id);


--
-- Name: temporadas temporadas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temporadas
    ADD CONSTRAINT temporadas_pkey PRIMARY KEY (id);


--
-- Name: tipos_producto tipos_producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_producto
    ADD CONSTRAINT tipos_producto_pkey PRIMARY KEY (id);


--
-- Name: transacciones_pago transacciones_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago
    ADD CONSTRAINT transacciones_pago_pkey PRIMARY KEY (id);


--
-- Name: transacciones_pago transacciones_pago_transaction_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago
    ADD CONSTRAINT transacciones_pago_transaction_id_key UNIQUE (transaction_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_session_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_session_token_key UNIQUE (session_token);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_firebase_uid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_firebase_uid_key UNIQUE (firebase_uid);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: ventas ventas_codigo_entrega_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_codigo_entrega_key UNIQUE (codigo_entrega);


--
-- Name: ventas ventas_folio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_folio_key UNIQUE (folio);


--
-- Name: ventas ventas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_pkey PRIMARY KEY (id);


--
-- Name: visitas_sitio visitas_sitio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visitas_sitio
    ADD CONSTRAINT visitas_sitio_pkey PRIMARY KEY (id);


--
-- Name: webhooks_pasarela webhooks_pasarela_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks_pasarela
    ADD CONSTRAINT webhooks_pasarela_pkey PRIMARY KEY (id);


--
-- Name: zonas_entrega zonas_entrega_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas_entrega
    ADD CONSTRAINT zonas_entrega_nombre_key UNIQUE (nombre);


--
-- Name: zonas_entrega zonas_entrega_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas_entrega
    ADD CONSTRAINT zonas_entrega_pkey PRIMARY KEY (id);


--
-- Name: idx_abonos_apartado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_abonos_apartado ON public.abonos USING btree (apartado_id);


--
-- Name: idx_abonos_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_abonos_estado ON public.abonos USING btree (estado);


--
-- Name: idx_alertas_inventario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alertas_inventario ON public.alertas_inventario USING btree (producto_id, resuelta);


--
-- Name: idx_apartados_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apartados_cliente ON public.apartados USING btree (cliente_id);


--
-- Name: idx_apartados_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apartados_estado ON public.apartados USING btree (estado);


--
-- Name: idx_apartados_trabajador; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apartados_trabajador ON public.apartados USING btree (trabajador_id);


--
-- Name: idx_apartados_venta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apartados_venta ON public.apartados USING btree (venta_id);


--
-- Name: idx_atributos_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_atributos_producto ON public.atributos_personalizacion USING btree (producto_id);


--
-- Name: idx_auditoria_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_fecha ON public.auditoria USING btree (fecha_operacion);


--
-- Name: idx_auditoria_tabla; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_tabla ON public.auditoria USING btree (tabla, registro_id);


--
-- Name: idx_carrito_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_carrito_usuario ON public.carrito USING btree (usuario_id);


--
-- Name: idx_categorias_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categorias_activo ON public.categorias USING btree (activo);


--
-- Name: idx_categorias_padre; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categorias_padre ON public.categorias USING btree (categoria_padre_id);


--
-- Name: idx_clientes_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clientes_email ON public.clientes USING btree (email);


--
-- Name: idx_clientes_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clientes_user ON public.clientes USING btree (user_id);


--
-- Name: idx_coleccion_productos_coleccion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coleccion_productos_coleccion ON public.coleccion_productos USING btree (coleccion_id);


--
-- Name: idx_coleccion_productos_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coleccion_productos_producto ON public.coleccion_productos USING btree (producto_id);


--
-- Name: idx_comentarios_noticias_noticia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_comentarios_noticias_noticia ON public.comentarios_noticias USING btree (noticia_id);


--
-- Name: idx_compras_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_compras_fecha ON public.compras USING btree (fecha_compra);


--
-- Name: idx_compras_proveedor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_compras_proveedor ON public.compras USING btree (proveedor_id);


--
-- Name: idx_contenidos_seccion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contenidos_seccion ON public.contenidos USING btree (seccion_id, orden);


--
-- Name: idx_cupones_clientes_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cupones_clientes_cliente ON public.cupones_clientes USING btree (cliente_id);


--
-- Name: idx_cupones_clientes_promocion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cupones_clientes_promocion ON public.cupones_clientes USING btree (promocion_id);


--
-- Name: idx_detalle_compras; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_detalle_compras ON public.detalle_compras USING btree (compra_id);


--
-- Name: idx_detalle_ventas; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_detalle_ventas ON public.detalle_ventas USING btree (venta_id);


--
-- Name: idx_direcciones_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_direcciones_cliente ON public.direcciones_cliente USING btree (cliente_id);


--
-- Name: idx_dispositivos_push_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispositivos_push_usuario ON public.dispositivos_push USING btree (usuario_id);


--
-- Name: idx_historial_promo_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historial_promo_cliente ON public.historial_promociones USING btree (cliente_id);


--
-- Name: idx_historial_venta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historial_venta ON public.historial_estado_venta USING btree (venta_id);


--
-- Name: idx_imagenes_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_imagenes_producto ON public.imagenes_producto USING btree (producto_id);


--
-- Name: idx_login_attempts_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_attempts_user ON public.login_attempts USING btree (user_id);


--
-- Name: idx_login_security_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_security_user ON public.login_security USING btree (user_id);


--
-- Name: idx_metodos_pago_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_metodos_pago_activo ON public.metodos_pago USING btree (activo, orden);


--
-- Name: idx_mfa_backup_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mfa_backup_user ON public.mfa_backup_codes USING btree (user_id);


--
-- Name: idx_movimientos_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_fecha ON public.movimientos_inventario USING btree (fecha_movimiento);


--
-- Name: idx_movimientos_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_producto ON public.movimientos_inventario USING btree (producto_id);


--
-- Name: idx_oauth_codes_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_oauth_codes_code ON public.oauth_codes USING btree (code);


--
-- Name: idx_oauth_tokens_access; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_oauth_tokens_access ON public.oauth_tokens USING btree (access_token);


--
-- Name: idx_oauth_tokens_refresh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_oauth_tokens_refresh ON public.oauth_tokens USING btree (refresh_token);


--
-- Name: idx_paginas_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_paginas_activo ON public.paginas USING btree (activo) WHERE (activo = true);


--
-- Name: idx_paginas_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_paginas_slug ON public.paginas USING btree (slug);


--
-- Name: idx_pers_grupos_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pers_grupos_categoria ON public.personalizacion_grupos USING btree (categoria_id);


--
-- Name: idx_pers_grupos_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pers_grupos_producto ON public.personalizacion_grupos USING btree (producto_id);


--
-- Name: idx_pers_opciones_grupo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pers_opciones_grupo ON public.personalizacion_opciones USING btree (grupo_id);


--
-- Name: idx_productos_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_productos_activo ON public.productos USING btree (activo) WHERE (activo = true);


--
-- Name: idx_productos_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_productos_categoria ON public.productos USING btree (categoria_id);


--
-- Name: idx_productos_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_productos_codigo ON public.productos USING btree (codigo);


--
-- Name: idx_productos_destacado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_productos_destacado ON public.productos USING btree (es_destacado) WHERE (es_destacado = true);


--
-- Name: idx_productos_proveedor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_productos_proveedor ON public.productos USING btree (proveedor_id);


--
-- Name: idx_promociones_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promociones_codigo ON public.promociones USING btree (codigo_cupon);


--
-- Name: idx_promociones_vigencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promociones_vigencia ON public.promociones USING btree (fecha_inicio, fecha_fin) WHERE (activo = true);


--
-- Name: idx_proveedores_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_proveedores_activo ON public.proveedores USING btree (activo);


--
-- Name: idx_request_logs_duration; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_logs_duration ON public.request_logs USING btree (duration_ms DESC);


--
-- Name: idx_request_logs_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_logs_endpoint ON public.request_logs USING btree (endpoint);


--
-- Name: idx_request_logs_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_logs_fecha ON public.request_logs USING btree (fecha DESC);


--
-- Name: idx_request_logs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_logs_status ON public.request_logs USING btree (status_code);


--
-- Name: idx_resenas_producto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_resenas_producto_id ON public.resenas_producto USING btree (producto_id);


--
-- Name: idx_secciones_pagina; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_secciones_pagina ON public.secciones USING btree (pagina_id, orden);


--
-- Name: idx_sessions_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_token ON public.user_sessions USING btree (session_token);


--
-- Name: idx_sessions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessions_user ON public.user_sessions USING btree (user_id);


--
-- Name: idx_solicitudes_personalizacion_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_solicitudes_personalizacion_cliente ON public.solicitudes_personalizacion USING btree (cliente_id);


--
-- Name: idx_solicitudes_personalizacion_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_solicitudes_personalizacion_estado ON public.solicitudes_personalizacion USING btree (estado);


--
-- Name: idx_solicitudes_personalizacion_producto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_solicitudes_personalizacion_producto ON public.solicitudes_personalizacion USING btree (producto_id);


--
-- Name: idx_system_errors_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_errors_fecha ON public.system_errors USING btree (fecha DESC);


--
-- Name: idx_system_errors_resuelta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_errors_resuelta ON public.system_errors USING btree (resuelta);


--
-- Name: idx_system_errors_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_errors_tipo ON public.system_errors USING btree (tipo);


--
-- Name: idx_temporadas_vigentes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_temporadas_vigentes ON public.temporadas USING btree (fecha_inicio, fecha_fin) WHERE (activo = true);


--
-- Name: idx_tipos_producto_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tipos_producto_activo ON public.tipos_producto USING btree (activo);


--
-- Name: idx_transacciones_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transacciones_estado ON public.transacciones_pago USING btree (estado);


--
-- Name: idx_transacciones_venta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transacciones_venta ON public.transacciones_pago USING btree (venta_id);


--
-- Name: idx_usuarios_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_activo ON public.usuarios USING btree (activo);


--
-- Name: idx_usuarios_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);


--
-- Name: idx_usuarios_firebase_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_firebase_uid ON public.usuarios USING btree (firebase_uid);


--
-- Name: idx_ventas_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ventas_cliente ON public.ventas USING btree (cliente_id);


--
-- Name: idx_ventas_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ventas_estado ON public.ventas USING btree (estado);


--
-- Name: idx_ventas_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ventas_fecha ON public.ventas USING btree (fecha_creacion);


--
-- Name: idx_ventas_folio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ventas_folio ON public.ventas USING btree (folio);


--
-- Name: idx_ventas_trabajador; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ventas_trabajador ON public.ventas USING btree (trabajador_id);


--
-- Name: idx_visitas_sitio_creado_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitas_sitio_creado_en ON public.visitas_sitio USING btree (creado_en);


--
-- Name: idx_visitas_sitio_visitor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visitas_sitio_visitor ON public.visitas_sitio USING btree (visitor_id);


--
-- Name: idx_webhooks_procesado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_webhooks_procesado ON public.webhooks_pasarela USING btree (procesado);


--
-- Name: productos trigger_actualizar_producto; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_actualizar_producto BEFORE INSERT OR UPDATE ON public.productos FOR EACH ROW EXECUTE FUNCTION public.actualizar_campos_producto();


--
-- Name: movimientos_inventario trigger_actualizar_stock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_actualizar_stock AFTER INSERT ON public.movimientos_inventario FOR EACH ROW EXECUTE FUNCTION public.actualizar_stock_producto();


--
-- Name: ventas trigger_historial_venta; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_historial_venta AFTER UPDATE ON public.ventas FOR EACH ROW EXECUTE FUNCTION public.registrar_historial_venta();


--
-- Name: categorias trigger_sync_categoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_sync_categoria AFTER UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.sincronizar_categoria_producto();


--
-- Name: usuarios trigger_sync_login; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_sync_login AFTER INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.sincronizar_login_security();


--
-- Name: proveedores trigger_sync_proveedor; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_sync_proveedor AFTER UPDATE ON public.proveedores FOR EACH ROW EXECUTE FUNCTION public.sincronizar_proveedor_producto();


--
-- Name: detalle_ventas trigger_total_articulos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_total_articulos AFTER INSERT OR DELETE OR UPDATE ON public.detalle_ventas FOR EACH ROW EXECUTE FUNCTION public.actualizar_total_articulos();


--
-- Name: ventas trigger_uso_promocion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_uso_promocion AFTER INSERT ON public.ventas FOR EACH ROW EXECUTE FUNCTION public.registrar_uso_promocion();


--
-- Name: movimientos_inventario trigger_verificar_stock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_verificar_stock AFTER INSERT ON public.movimientos_inventario FOR EACH ROW EXECUTE FUNCTION public.verificar_stock_productos();


--
-- Name: apartados apartados_plan_abono_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT apartados_plan_abono_id_fkey FOREIGN KEY (plan_abono_id) REFERENCES public.planes_abono(id);


--
-- Name: carrito carrito_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito
    ADD CONSTRAINT carrito_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: carrito carrito_solicitud_personalizacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito
    ADD CONSTRAINT carrito_solicitud_personalizacion_id_fkey FOREIGN KEY (solicitud_personalizacion_id) REFERENCES public.solicitudes_personalizacion(id) ON DELETE SET NULL;


--
-- Name: carrito carrito_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrito
    ADD CONSTRAINT carrito_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: coleccion_productos coleccion_productos_coleccion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coleccion_productos
    ADD CONSTRAINT coleccion_productos_coleccion_id_fkey FOREIGN KEY (coleccion_id) REFERENCES public.colecciones(id) ON DELETE CASCADE;


--
-- Name: coleccion_productos coleccion_productos_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coleccion_productos
    ADD CONSTRAINT coleccion_productos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: colecciones colecciones_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colecciones
    ADD CONSTRAINT colecciones_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: comentarios_noticias comentarios_noticias_noticia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios_noticias
    ADD CONSTRAINT comentarios_noticias_noticia_id_fkey FOREIGN KEY (noticia_id) REFERENCES public.noticias(id) ON DELETE CASCADE;


--
-- Name: comentarios_noticias comentarios_noticias_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios_noticias
    ADD CONSTRAINT comentarios_noticias_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: cupones_clientes cupones_clientes_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cupones_clientes
    ADD CONSTRAINT cupones_clientes_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;


--
-- Name: cupones_clientes cupones_clientes_promocion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cupones_clientes
    ADD CONSTRAINT cupones_clientes_promocion_id_fkey FOREIGN KEY (promocion_id) REFERENCES public.promociones(id) ON DELETE CASCADE;


--
-- Name: detalle_ventas detalle_ventas_solicitud_personalizacion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_ventas
    ADD CONSTRAINT detalle_ventas_solicitud_personalizacion_id_fkey FOREIGN KEY (solicitud_personalizacion_id) REFERENCES public.solicitudes_personalizacion(id) ON DELETE SET NULL;


--
-- Name: dispositivos_push dispositivos_push_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos_push
    ADD CONSTRAINT dispositivos_push_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: favoritos favoritos_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: favoritos favoritos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favoritos
    ADD CONSTRAINT favoritos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: abonos fk_abono_apartado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos
    ADD CONSTRAINT fk_abono_apartado FOREIGN KEY (apartado_id) REFERENCES public.apartados(id);


--
-- Name: abonos fk_abono_metodo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos
    ADD CONSTRAINT fk_abono_metodo FOREIGN KEY (metodo_pago_id) REFERENCES public.metodos_pago(id);


--
-- Name: abonos fk_abono_registrado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos
    ADD CONSTRAINT fk_abono_registrado FOREIGN KEY (registrado_por) REFERENCES public.usuarios(id);


--
-- Name: abonos fk_abono_transaccion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonos
    ADD CONSTRAINT fk_abono_transaccion FOREIGN KEY (transaccion_id) REFERENCES public.transacciones_pago(id);


--
-- Name: alertas_inventario fk_alerta_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alertas_inventario
    ADD CONSTRAINT fk_alerta_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: alertas_inventario fk_alerta_resuelta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alertas_inventario
    ADD CONSTRAINT fk_alerta_resuelta FOREIGN KEY (resuelta_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: apartados fk_apartado_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id);


--
-- Name: apartados fk_apartado_cancelado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_cancelado FOREIGN KEY (cancelado_por) REFERENCES public.usuarios(id);


--
-- Name: apartados fk_apartado_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_cliente FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: apartados fk_apartado_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id);


--
-- Name: apartados fk_apartado_trabajador; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_trabajador FOREIGN KEY (trabajador_id) REFERENCES public.usuarios(id);


--
-- Name: apartados fk_apartado_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartados
    ADD CONSTRAINT fk_apartado_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: atributos_personalizacion fk_atributos_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atributos_personalizacion
    ADD CONSTRAINT fk_atributos_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: auditoria fk_auditoria_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: categorias fk_categorias_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT fk_categorias_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: categorias fk_categorias_padre; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT fk_categorias_padre FOREIGN KEY (categoria_padre_id) REFERENCES public.categorias(id) ON DELETE SET NULL;


--
-- Name: clientes fk_clientes_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT fk_clientes_user FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: compras fk_compras_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT fk_compras_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: compras fk_compras_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT fk_compras_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: compras fk_compras_proveedor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT fk_compras_proveedor FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);


--
-- Name: configuracion fk_config_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracion
    ADD CONSTRAINT fk_config_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id);


--
-- Name: contenidos fk_contenidos_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contenidos
    ADD CONSTRAINT fk_contenidos_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: contenidos fk_contenidos_seccion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contenidos
    ADD CONSTRAINT fk_contenidos_seccion FOREIGN KEY (seccion_id) REFERENCES public.secciones(id) ON DELETE CASCADE;


--
-- Name: detalle_compras fk_detalle_compra; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_compras
    ADD CONSTRAINT fk_detalle_compra FOREIGN KEY (compra_id) REFERENCES public.compras(id) ON DELETE CASCADE;


--
-- Name: detalle_compras fk_detalle_compra_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_compras
    ADD CONSTRAINT fk_detalle_compra_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id);


--
-- Name: detalle_ventas fk_detalle_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_ventas
    ADD CONSTRAINT fk_detalle_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id) ON DELETE CASCADE;


--
-- Name: detalle_ventas fk_detalle_venta_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_ventas
    ADD CONSTRAINT fk_detalle_venta_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id);


--
-- Name: direcciones_cliente fk_direcciones_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direcciones_cliente
    ADD CONSTRAINT fk_direcciones_cliente FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;


--
-- Name: preguntas_frecuentes fk_faq_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preguntas_frecuentes
    ADD CONSTRAINT fk_faq_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: preguntas_frecuentes fk_faq_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preguntas_frecuentes
    ADD CONSTRAINT fk_faq_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: historial_promociones fk_historial_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones
    ADD CONSTRAINT fk_historial_cliente FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;


--
-- Name: historial_estado_venta fk_historial_modificado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_estado_venta
    ADD CONSTRAINT fk_historial_modificado FOREIGN KEY (modificado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: historial_promociones fk_historial_promo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones
    ADD CONSTRAINT fk_historial_promo FOREIGN KEY (promocion_id) REFERENCES public.promociones(id) ON DELETE CASCADE;


--
-- Name: historial_estado_venta fk_historial_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_estado_venta
    ADD CONSTRAINT fk_historial_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id) ON DELETE CASCADE;


--
-- Name: historial_promociones fk_historial_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_promociones
    ADD CONSTRAINT fk_historial_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id) ON DELETE SET NULL;


--
-- Name: imagenes_producto fk_imagenes_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagenes_producto
    ADD CONSTRAINT fk_imagenes_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: login_attempts fk_login_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_attempts
    ADD CONSTRAINT fk_login_user FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: metodos_pago fk_metodos_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodos_pago
    ADD CONSTRAINT fk_metodos_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: metodos_pago fk_metodos_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metodos_pago
    ADD CONSTRAINT fk_metodos_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: mfa_backup_codes fk_mfa_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mfa_backup_codes
    ADD CONSTRAINT fk_mfa_user FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: movimientos_inventario fk_movimiento_compra; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT fk_movimiento_compra FOREIGN KEY (compra_id) REFERENCES public.compras(id);


--
-- Name: movimientos_inventario fk_movimiento_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT fk_movimiento_producto FOREIGN KEY (producto_id) REFERENCES public.productos(id);


--
-- Name: movimientos_inventario fk_movimiento_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT fk_movimiento_usuario FOREIGN KEY (realizado_por) REFERENCES public.usuarios(id);


--
-- Name: movimientos_inventario fk_movimiento_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_inventario
    ADD CONSTRAINT fk_movimiento_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: notificaciones fk_notif_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT fk_notif_cliente FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: notificaciones fk_notif_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT fk_notif_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id);


--
-- Name: paginas fk_paginas_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paginas
    ADD CONSTRAINT fk_paginas_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: paginas fk_paginas_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paginas
    ADD CONSTRAINT fk_paginas_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: planes_abono fk_plan_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_abono
    ADD CONSTRAINT fk_plan_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id);


--
-- Name: productos fk_productos_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: productos fk_productos_categoria; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_categoria FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: productos fk_productos_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: productos fk_productos_proveedor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_proveedor FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id) ON DELETE SET NULL;


--
-- Name: productos fk_productos_temporada; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_temporada FOREIGN KEY (temporada_id) REFERENCES public.temporadas(id) ON DELETE SET NULL;


--
-- Name: productos fk_productos_tipo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_tipo FOREIGN KEY (tipo_producto_id) REFERENCES public.tipos_producto(id) ON DELETE SET NULL;


--
-- Name: promociones fk_promociones_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT fk_promociones_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: promociones fk_promociones_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT fk_promociones_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: proveedores fk_proveedores_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT fk_proveedores_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id);


--
-- Name: proveedores fk_proveedores_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT fk_proveedores_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: respaldos_historial fk_respaldo_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.respaldos_historial
    ADD CONSTRAINT fk_respaldo_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: secciones fk_secciones_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secciones
    ADD CONSTRAINT fk_secciones_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: secciones fk_secciones_pagina; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secciones
    ADD CONSTRAINT fk_secciones_pagina FOREIGN KEY (pagina_id) REFERENCES public.paginas(id) ON DELETE CASCADE;


--
-- Name: security_questions fk_security_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_questions
    ADD CONSTRAINT fk_security_user FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: login_security fk_security_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_security
    ADD CONSTRAINT fk_security_user_id FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: user_sessions fk_sessions_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: temporadas fk_temporadas_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temporadas
    ADD CONSTRAINT fk_temporadas_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: tipos_producto fk_tipos_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_producto
    ADD CONSTRAINT fk_tipos_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: transacciones_pago fk_transaccion_metodo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago
    ADD CONSTRAINT fk_transaccion_metodo FOREIGN KEY (metodo_pago_id) REFERENCES public.metodos_pago(id);


--
-- Name: transacciones_pago fk_transaccion_procesado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago
    ADD CONSTRAINT fk_transaccion_procesado FOREIGN KEY (procesado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: transacciones_pago fk_transaccion_venta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transacciones_pago
    ADD CONSTRAINT fk_transaccion_venta FOREIGN KEY (venta_id) REFERENCES public.ventas(id) ON DELETE CASCADE;


--
-- Name: ventas fk_ventas_actualizado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_actualizado FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: ventas fk_ventas_cancelado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_cancelado FOREIGN KEY (cancelado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: ventas fk_ventas_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_cliente FOREIGN KEY (cliente_id) REFERENCES public.clientes(id);


--
-- Name: ventas fk_ventas_creado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_creado FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: ventas fk_ventas_direccion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_direccion FOREIGN KEY (direccion_entrega_id) REFERENCES public.direcciones_cliente(id);


--
-- Name: ventas fk_ventas_metodo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_metodo FOREIGN KEY (metodo_pago_id) REFERENCES public.metodos_pago(id);


--
-- Name: ventas fk_ventas_promocion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_promocion FOREIGN KEY (promocion_id) REFERENCES public.promociones(id) ON DELETE SET NULL;


--
-- Name: webhooks_pasarela fk_webhook_metodo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks_pasarela
    ADD CONSTRAINT fk_webhook_metodo FOREIGN KEY (metodo_pago_id) REFERENCES public.metodos_pago(id);


--
-- Name: webhooks_pasarela fk_webhook_procesado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks_pasarela
    ADD CONSTRAINT fk_webhook_procesado FOREIGN KEY (procesado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: informacion_empresa informacion_empresa_actualizado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informacion_empresa
    ADD CONSTRAINT informacion_empresa_actualizado_por_fkey FOREIGN KEY (actualizado_por) REFERENCES public.usuarios(id);


--
-- Name: oauth_codes oauth_codes_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_codes
    ADD CONSTRAINT oauth_codes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: oauth_tokens oauth_tokens_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_tokens
    ADD CONSTRAINT oauth_tokens_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: personalizacion_grupos personalizacion_grupos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_grupos
    ADD CONSTRAINT personalizacion_grupos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id) ON DELETE CASCADE;


--
-- Name: personalizacion_grupos personalizacion_grupos_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_grupos
    ADD CONSTRAINT personalizacion_grupos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: personalizacion_opciones personalizacion_opciones_grupo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personalizacion_opciones
    ADD CONSTRAINT personalizacion_opciones_grupo_id_fkey FOREIGN KEY (grupo_id) REFERENCES public.personalizacion_grupos(id) ON DELETE CASCADE;


--
-- Name: request_logs request_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_logs
    ADD CONSTRAINT request_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: resenas_producto resenas_producto_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resenas_producto
    ADD CONSTRAINT resenas_producto_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id);


--
-- Name: resenas_producto resenas_producto_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resenas_producto
    ADD CONSTRAINT resenas_producto_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: solicitudes_cambio solicitudes_cambio_revisado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_cambio
    ADD CONSTRAINT solicitudes_cambio_revisado_por_fkey FOREIGN KEY (revisado_por) REFERENCES public.usuarios(id);


--
-- Name: solicitudes_cambio solicitudes_cambio_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_cambio
    ADD CONSTRAINT solicitudes_cambio_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: solicitudes_personalizacion solicitudes_personalizacion_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_personalizacion
    ADD CONSTRAINT solicitudes_personalizacion_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;


--
-- Name: solicitudes_personalizacion solicitudes_personalizacion_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_personalizacion
    ADD CONSTRAINT solicitudes_personalizacion_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE CASCADE;


--
-- Name: solicitudes_personalizacion solicitudes_personalizacion_respondido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitudes_personalizacion
    ADD CONSTRAINT solicitudes_personalizacion_respondido_por_fkey FOREIGN KEY (respondido_por) REFERENCES public.usuarios(id);


--
-- Name: system_errors system_errors_resuelta_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_errors
    ADD CONSTRAINT system_errors_resuelta_por_fkey FOREIGN KEY (resuelta_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: system_errors system_errors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_errors
    ADD CONSTRAINT system_errors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: ventas ventas_trabajador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT ventas_trabajador_id_fkey FOREIGN KEY (trabajador_id) REFERENCES public.usuarios(id);


--
-- Name: personalizacion_grupos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.personalizacion_grupos ENABLE ROW LEVEL SECURITY;

--
-- Name: personalizacion_opciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.personalizacion_opciones ENABLE ROW LEVEL SECURITY;

--
-- Name: temas_temporada; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.temas_temporada ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--


