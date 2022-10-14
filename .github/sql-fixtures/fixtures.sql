PGDMP  	                    	    z           taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6 |   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    7153289    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    7153413    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            �           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            D           1247    7153766    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            A           1247    7153757    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            1           1255    7153831 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          taiga    false            I           1255    7153848 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          taiga    false            2           1255    7153832 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          taiga    false            �            1259    7153783    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    taiga    false    833    833            3           1255    7153833 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          taiga    false    238            H           1255    7153847 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          taiga    false    833            G           1255    7153846 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          taiga    false    833            4           1255    7153834 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          taiga    false    833            6           1255    7153836    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          taiga    false            5           1255    7153835 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          taiga    false            E           1255    7153839 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            C           1255    7153837 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            D           1255    7153838 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          taiga    false            F           1255    7153840 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          taiga    false            �           3602    7153420    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          taiga    false    2    2    2    2            �            1259    7153373 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    7153371    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    7153382    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    7153380    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    7153366    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    7153364    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    7153343    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    7153341    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    7153334    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    7153332    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    7153292    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    7153290    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    7153598    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    7153423    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    7153421    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    7153430    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    7153428     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    7153455 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    7153453 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    7153813    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    836            �            1259    7153811    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    242            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    241            �            1259    7153781    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    238            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    237            �            1259    7153797    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    7153795 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    240            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    239            �            1259    7153849 3   project_references_68a650104f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68a650104f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68a650104f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153851 3   project_references_68aead644f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68aead644f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68aead644f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153853 3   project_references_68b4ae304f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68b4ae304f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68b4ae304f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153855 3   project_references_68bbe6284f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68bbe6284f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68bbe6284f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153857 3   project_references_68c446424f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68c446424f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68c446424f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153859 3   project_references_68ccaec24f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68ccaec24f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68ccaec24f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153861 3   project_references_68d41a684f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68d41a684f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68d41a684f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153863 3   project_references_68daaa9a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68daaa9a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68daaa9a4f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153865 3   project_references_68e0f6344f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68e0f6344f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68e0f6344f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153867 3   project_references_68e67ff04f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68e67ff04f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68e67ff04f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153869 3   project_references_68f046c04f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68f046c04f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68f046c04f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153871 3   project_references_68f5bfba4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68f5bfba4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68f5bfba4f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153873 3   project_references_68fd17d84f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_68fd17d84f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_68fd17d84f9d11ed88ef4074e0238e3a;
       public          taiga    false                        1259    7153875 3   project_references_6905dee04f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6905dee04f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6905dee04f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153877 3   project_references_690e26ea4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_690e26ea4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_690e26ea4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153879 3   project_references_69175d464f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_69175d464f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_69175d464f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153881 3   project_references_691d92424f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_691d92424f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_691d92424f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153883 3   project_references_6925f3884f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6925f3884f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6925f3884f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153885 3   project_references_692efc804f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_692efc804f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_692efc804f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153887 3   project_references_693719884f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_693719884f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_693719884f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153889 3   project_references_6b0ba42c4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b0ba42c4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b0ba42c4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153891 3   project_references_6b10a17a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b10a17a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b10a17a4f9d11ed88ef4074e0238e3a;
       public          taiga    false            	           1259    7153893 3   project_references_6b1673fc4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b1673fc4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b1673fc4f9d11ed88ef4074e0238e3a;
       public          taiga    false            
           1259    7153896 3   project_references_6b6ca74a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b6ca74a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b6ca74a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153898 3   project_references_6b7217344f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b7217344f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b7217344f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153900 3   project_references_6b7950c64f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b7950c64f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b7950c64f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153903 3   project_references_6b7d28864f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b7d28864f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b7d28864f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153905 3   project_references_6b82366e4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b82366e4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b82366e4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153907 3   project_references_6b87acb64f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b87acb64f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b87acb64f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153909 3   project_references_6b8d760a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b8d760a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b8d760a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153911 3   project_references_6b938cfc4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b938cfc4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b938cfc4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153913 3   project_references_6b99970a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b99970a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b99970a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153915 3   project_references_6b9f830e4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b9f830e4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b9f830e4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153917 3   project_references_6ba962164f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6ba962164f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6ba962164f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153919 3   project_references_6baeb4d24f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6baeb4d24f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6baeb4d24f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153921 3   project_references_6bbed29a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bbed29a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bbed29a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153923 3   project_references_6bc3ef284f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bc3ef284f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bc3ef284f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153925 3   project_references_6bc820a24f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bc820a24f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bc820a24f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153927 3   project_references_6bcda95a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bcda95a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bcda95a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153929 3   project_references_6bd7d6d24f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bd7d6d24f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bd7d6d24f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153931 3   project_references_6be010cc4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6be010cc4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6be010cc4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153933 3   project_references_6be7e0cc4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6be7e0cc4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6be7e0cc4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153935 3   project_references_6bf2dcca4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bf2dcca4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bf2dcca4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153937 3   project_references_6bfbf08a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6bfbf08a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6bfbf08a4f9d11ed88ef4074e0238e3a;
       public          taiga    false                       1259    7153939 3   project_references_6c3655184f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c3655184f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c3655184f9d11ed88ef4074e0238e3a;
       public          taiga    false                        1259    7153941 3   project_references_6c3bac844f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c3bac844f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c3bac844f9d11ed88ef4074e0238e3a;
       public          taiga    false            !           1259    7153943 3   project_references_6c42642a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c42642a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c42642a4f9d11ed88ef4074e0238e3a;
       public          taiga    false            "           1259    7153945 3   project_references_6c485f1a4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c485f1a4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c485f1a4f9d11ed88ef4074e0238e3a;
       public          taiga    false            #           1259    7153947 3   project_references_6c4eed804f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c4eed804f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c4eed804f9d11ed88ef4074e0238e3a;
       public          taiga    false            $           1259    7153949 3   project_references_6c55e7ca4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c55e7ca4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c55e7ca4f9d11ed88ef4074e0238e3a;
       public          taiga    false            %           1259    7153951 3   project_references_6c65107e4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c65107e4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c65107e4f9d11ed88ef4074e0238e3a;
       public          taiga    false            &           1259    7153953 3   project_references_6c6988e84f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c6988e84f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c6988e84f9d11ed88ef4074e0238e3a;
       public          taiga    false            '           1259    7153955 3   project_references_6c6f02784f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c6f02784f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c6f02784f9d11ed88ef4074e0238e3a;
       public          taiga    false            (           1259    7153957 3   project_references_6c7373c64f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c7373c64f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c7373c64f9d11ed88ef4074e0238e3a;
       public          taiga    false            )           1259    7153959 3   project_references_6ce9b9dc4f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6ce9b9dc4f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6ce9b9dc4f9d11ed88ef4074e0238e3a;
       public          taiga    false            *           1259    7153961 3   project_references_6d3c1da84f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d3c1da84f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d3c1da84f9d11ed88ef4074e0238e3a;
       public          taiga    false            +           1259    7153963 3   project_references_6d410b384f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d410b384f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d410b384f9d11ed88ef4074e0238e3a;
       public          taiga    false            ,           1259    7153965 3   project_references_718fd1564f9d11ed88ef4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_718fd1564f9d11ed88ef4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_718fd1564f9d11ed88ef4074e0238e3a;
       public          taiga    false            �            1259    7153555 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 :   DROP TABLE public.projects_invitations_projectinvitation;
       public         heap    taiga    false            �            1259    7153517 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    7153477    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(250) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    7153487    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    7153499    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    7153640    stories_story    TABLE     R  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" numeric(16,10) NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    7153686    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    7153676    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    taiga    false            �            1259    7153312    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    7153300 
   users_user    TABLE       CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone,
    lang character varying(20) NOT NULL
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    7153608    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    7153616    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    7153724 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    7153706    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    7153469    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false                       2604    7153816    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    241    242    242            �           2604    7153786    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    237    238    238            �           2604    7153800     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    239    240    240            \          0    7153373 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   �Y      ^          0    7153382    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   Z      Z          0    7153366    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   #Z      X          0    7153343    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   �]      V          0    7153334    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   �]      R          0    7153292    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   _      k          0    7153598    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    229   �a      `          0    7153423    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218    b      b          0    7153430    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   b      d          0    7153455 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   :b      x          0    7153813    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    242   Wb      t          0    7153783    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    238   tb      v          0    7153797    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    240   �b      j          0    7153555 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    228   �b      i          0    7153517 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    227   l      f          0    7153477    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    224   ;y      g          0    7153487    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    225   *�      h          0    7153499    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    226   o�      n          0    7153640    stories_story 
   TABLE DATA              COPY public.stories_story (id, created_at, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    232   ˖      p          0    7153686    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    234   �      o          0    7153676    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    233   �      T          0    7153312    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   �      S          0    7153300 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification, lang) FROM stdin;
    public          taiga    false    205   �      l          0    7153608    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    230   �      m          0    7153616    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    231   +      r          0    7153724 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    236   z'      q          0    7153706    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    235   w/      e          0    7153469    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    223   �3      �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    211            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    207            �           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 38, true);
          public          taiga    false    203            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    217            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    219            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221            �           0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    241            �           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    237            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    239            �           0    0 3   project_references_68a650104f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68a650104f9d11ed88ef4074e0238e3a', 19, true);
          public          taiga    false    243            �           0    0 3   project_references_68aead644f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68aead644f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    244            �           0    0 3   project_references_68b4ae304f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68b4ae304f9d11ed88ef4074e0238e3a', 13, true);
          public          taiga    false    245            �           0    0 3   project_references_68bbe6284f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68bbe6284f9d11ed88ef4074e0238e3a', 27, true);
          public          taiga    false    246            �           0    0 3   project_references_68c446424f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68c446424f9d11ed88ef4074e0238e3a', 29, true);
          public          taiga    false    247            �           0    0 3   project_references_68ccaec24f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_68ccaec24f9d11ed88ef4074e0238e3a', 2, true);
          public          taiga    false    248            �           0    0 3   project_references_68d41a684f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68d41a684f9d11ed88ef4074e0238e3a', 20, true);
          public          taiga    false    249            �           0    0 3   project_references_68daaa9a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_68daaa9a4f9d11ed88ef4074e0238e3a', 8, true);
          public          taiga    false    250            �           0    0 3   project_references_68e0f6344f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68e0f6344f9d11ed88ef4074e0238e3a', 11, true);
          public          taiga    false    251            �           0    0 3   project_references_68e67ff04f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_68e67ff04f9d11ed88ef4074e0238e3a', 6, true);
          public          taiga    false    252            �           0    0 3   project_references_68f046c04f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_68f046c04f9d11ed88ef4074e0238e3a', 14, true);
          public          taiga    false    253            �           0    0 3   project_references_68f5bfba4f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_68f5bfba4f9d11ed88ef4074e0238e3a', 9, true);
          public          taiga    false    254            �           0    0 3   project_references_68fd17d84f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_68fd17d84f9d11ed88ef4074e0238e3a', 8, true);
          public          taiga    false    255            �           0    0 3   project_references_6905dee04f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6905dee04f9d11ed88ef4074e0238e3a', 16, true);
          public          taiga    false    256            �           0    0 3   project_references_690e26ea4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_690e26ea4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    257            �           0    0 3   project_references_69175d464f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_69175d464f9d11ed88ef4074e0238e3a', 24, true);
          public          taiga    false    258            �           0    0 3   project_references_691d92424f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_691d92424f9d11ed88ef4074e0238e3a', 4, true);
          public          taiga    false    259            �           0    0 3   project_references_6925f3884f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6925f3884f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    260            �           0    0 3   project_references_692efc804f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_692efc804f9d11ed88ef4074e0238e3a', 15, true);
          public          taiga    false    261            �           0    0 3   project_references_693719884f9d11ed88ef4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_693719884f9d11ed88ef4074e0238e3a', 4, true);
          public          taiga    false    262            �           0    0 3   project_references_6b0ba42c4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b0ba42c4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    263            �           0    0 3   project_references_6b10a17a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b10a17a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    264            �           0    0 3   project_references_6b1673fc4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b1673fc4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    265            �           0    0 3   project_references_6b6ca74a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b6ca74a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    266            �           0    0 3   project_references_6b7217344f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b7217344f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    267            �           0    0 3   project_references_6b7950c64f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b7950c64f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    268            �           0    0 3   project_references_6b7d28864f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b7d28864f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    269            �           0    0 3   project_references_6b82366e4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b82366e4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    270            �           0    0 3   project_references_6b87acb64f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b87acb64f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    271            �           0    0 3   project_references_6b8d760a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b8d760a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    272            �           0    0 3   project_references_6b938cfc4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b938cfc4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    273            �           0    0 3   project_references_6b99970a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b99970a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    274            �           0    0 3   project_references_6b9f830e4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b9f830e4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    275            �           0    0 3   project_references_6ba962164f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6ba962164f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    276            �           0    0 3   project_references_6baeb4d24f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6baeb4d24f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    277            �           0    0 3   project_references_6bbed29a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bbed29a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    278            �           0    0 3   project_references_6bc3ef284f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bc3ef284f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    279            �           0    0 3   project_references_6bc820a24f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bc820a24f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    280            �           0    0 3   project_references_6bcda95a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bcda95a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    281            �           0    0 3   project_references_6bd7d6d24f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bd7d6d24f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    282            �           0    0 3   project_references_6be010cc4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6be010cc4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    283            �           0    0 3   project_references_6be7e0cc4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6be7e0cc4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    284            �           0    0 3   project_references_6bf2dcca4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bf2dcca4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    285            �           0    0 3   project_references_6bfbf08a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6bfbf08a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    286            �           0    0 3   project_references_6c3655184f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c3655184f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    287            �           0    0 3   project_references_6c3bac844f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c3bac844f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    288            �           0    0 3   project_references_6c42642a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c42642a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    289            �           0    0 3   project_references_6c485f1a4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c485f1a4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    290            �           0    0 3   project_references_6c4eed804f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c4eed804f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    291            �           0    0 3   project_references_6c55e7ca4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c55e7ca4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    292            �           0    0 3   project_references_6c65107e4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c65107e4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    293            �           0    0 3   project_references_6c6988e84f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c6988e84f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    294            �           0    0 3   project_references_6c6f02784f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c6f02784f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    295            �           0    0 3   project_references_6c7373c64f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c7373c64f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    296            �           0    0 3   project_references_6ce9b9dc4f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6ce9b9dc4f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    297                        0    0 3   project_references_6d3c1da84f9d11ed88ef4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6d3c1da84f9d11ed88ef4074e0238e3a', 1, false);
          public          taiga    false    298                       0    0 3   project_references_6d410b384f9d11ed88ef4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_6d410b384f9d11ed88ef4074e0238e3a', 1000, true);
          public          taiga    false    299                       0    0 3   project_references_718fd1564f9d11ed88ef4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_718fd1564f9d11ed88ef4074e0238e3a', 2000, true);
          public          taiga    false    300            #           2606    7153411    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            (           2606    7153397 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            +           2606    7153386 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            %           2606    7153377    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214                       2606    7153388 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212                        2606    7153370 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212                       2606    7153351 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210                       2606    7153340 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208                       2606    7153338 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208                       2606    7153299 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204            o           2606    7153605 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    229            /           2606    7153427 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            3           2606    7153438 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            5           2606    7153436 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            9           2606    7153434 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            >           2606    7153461 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            @           2606    7153463 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222            �           2606    7153819 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    242            �           2606    7153794 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    238            �           2606    7153803 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    240            �           2606    7153805 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    240    240    240            d           2606    7153561 ^   projects_invitations_projectinvitation projects_invitations_pro_email_project_id_b147d04b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq;
       public            taiga    false    228    228            g           2606    7153559 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    228            ]           2606    7153523 `   projects_memberships_projectmembership projects_memberships_pro_user_id_project_id_fac8390b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq;
       public            taiga    false    227    227            _           2606    7153521 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    227            K           2606    7153484 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    224            N           2606    7153486 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    224            Q           2606    7153494 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    225            T           2606    7153496 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    225            V           2606    7153506 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    226            [           2606    7153508 S   projects_roles_projectrole projects_roles_projectrole_slug_project_id_ef23bf22_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq UNIQUE (slug, project_id);
 }   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq;
       public            taiga    false    226    226            ~           2606    7153647     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    232            �           2606    7153650 8   stories_story stories_story_ref_project_id_ccca2722_uniq 
   CONSTRAINT     ~   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_ref_project_id_ccca2722_uniq UNIQUE (ref, project_id);
 b   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_ref_project_id_ccca2722_uniq;
       public            taiga    false    232    232            �           2606    7153690 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    234            �           2606    7153692 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    234            �           2606    7153685 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    233            �           2606    7153683 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    233                       2606    7153323 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    206    206                       2606    7153319 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206                       2606    7153311    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            	           2606    7153307    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205                       2606    7153309 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205            r           2606    7153615 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    230            u           2606    7153625 C   workflows_workflow workflows_workflow_slug_project_id_80394f0d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq UNIQUE (slug, project_id);
 m   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq;
       public            taiga    false    230    230            w           2606    7153623 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    231            y           2606    7153633 P   workflows_workflowstatus workflows_workflowstatus_slug_workflow_id_06486b8e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq UNIQUE (slug, workflow_id);
 z   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq;
       public            taiga    false    231    231            �           2606    7153730 f   workspaces_memberships_workspacemembership workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq;
       public            taiga    false    236    236            �           2606    7153728 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    236            �           2606    7153713 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    235            �           2606    7153715 ]   workspaces_roles_workspacerole workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq UNIQUE (slug, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq;
       public            taiga    false    235    235            D           2606    7153473 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    223            G           2606    7153475 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    223            !           1259    7153412    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            &           1259    7153408 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            )           1259    7153409 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216                       1259    7153394 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212                       1259    7153362 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210                       1259    7153363 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210            m           1259    7153607 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    229            p           1259    7153606 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    229            ,           1259    7153441 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            -           1259    7153442 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218            0           1259    7153439 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            1           1259    7153440 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            6           1259    7153450 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            7           1259    7153451 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            :           1259    7153452 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            ;           1259    7153448 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            <           1259    7153449 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220            �           1259    7153829     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    242            �           1259    7153828    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    833    238    238    238            �           1259    7153826    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    833    238    238            �           1259    7153827 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    238            �           1259    7153825 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    238    238    833            �           1259    7153830 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    240            e           1259    7153592 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    228            h           1259    7153593 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    228            i           1259    7153594 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    228            j           1259    7153595 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    228            k           1259    7153596 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    228            l           1259    7153597 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    228            `           1259    7153539 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    227            a           1259    7153540 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    227            b           1259    7153541 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    227            H           1259    7153553 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    224    224            I           1259    7153547 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    224            L           1259    7153497 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    224            O           1259    7153554 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    224            R           1259    7153498 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    225            W           1259    7153516 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    226            X           1259    7153514 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    226            Y           1259    7153515 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    226            {           1259    7153648    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    232    232            |           1259    7153672 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    232                       1259    7153673 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    232            �           1259    7153671    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    232            �           1259    7153674     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    232            �           1259    7153675 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    232            �           1259    7153699 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    233            �           1259    7153698 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    233                       1259    7153329    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206                       1259    7153330     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206                       1259    7153331    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206                       1259    7153321    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            
           1259    7153320 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205            s           1259    7153631 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    230            z           1259    7153639 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    231            �           1259    7153748 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    236            �           1259    7153746 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    236            �           1259    7153747 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    236            �           1259    7153721 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    235            �           1259    7153722 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    235            �           1259    7153723 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    235            A           1259    7153754 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    223    223            B           1259    7153755 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    223            E           1259    7153476 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    223            �           2620    7153841 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    833    310    238    238            �           2620    7153845 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    326    238            �           2620    7153844 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    238    238    238    325    833            �           2620    7153843 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    238    323    238    833            �           2620    7153842 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    238    324    238            �           2606    7153403 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    212    3104    216            �           2606    7153398 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    3109    214    216            �           2606    7153389 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    3095    208    212            �           2606    7153352 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    210    208    3095            �           2606    7153357 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    3081    210    205            �           2606    7153443 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    220    3119    218            �           2606    7153464 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    220    3129    222            �           2606    7153820 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    238    3232    242            �           2606    7153806 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    238    3232    240            �           2606    7153562 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    228    205    3081            �           2606    7153567 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    228    224    3147            �           2606    7153572 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    7153577 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    7153582 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    228    3158    226            �           2606    7153587 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    7153524 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    3147    227    224            �           2606    7153529 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    3158    227    226            �           2606    7153534 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    3081    227    205            �           2606    7153542 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    3081    224    205            �           2606    7153548 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    224    3140    223            �           2606    7153509 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    226    224    3147            �           2606    7153651 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    205    232    3081            �           2606    7153656 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    224    232    3147            �           2606    7153661 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    231    3191    232            �           2606    7153666 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    3186    232    230            �           2606    7153700 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    233    3210    234            �           2606    7153693 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    208    3095    233            �           2606    7153324 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    3081    206    205            �           2606    7153626 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    3147    224    230            �           2606    7153634 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    3186    231    230            �           2606    7153731 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    236    3216    235            �           2606    7153736 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    236    3081    205            �           2606    7153741 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    223    3140    236            �           2606    7153716 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    3140    223    235            �           2606    7153749 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    223    205    3081            \      xڋ���� � �      ^      xڋ���� � �      Z   �  x�u�[��0E��U���ś�l#U)�(\�gjv�Zt���7H��%� F�짬��:O���l�zZeԾ����;���O7�~���{�[��U����gk�N�]㺎�r����Y�6ԕ�`J�E�4	ם��e~=U����\�\�/@u
� ��J �l��}�e��[�T�,�kw�MIE(2HVԇ���d�Z�sjH5��j�=��\i�R5d@��:�X,��BN�D�i�9/��g���>�첾�OU;�swt�F�0x�y6+�䡐�'��M�5���z��V5�ﱦ�Zn
����4r;�Ľ|��A�w�|��P-/���(�s��.�輣��.rAu��.p����^�l�>ƭߎG����u]����4K�lb�l8��,�a1�O�4�$-�c�{�&y�V�ɓ�'wRO�EI���Ey�6�A�4u��1��{8�\jh��
�Q�.>P�-N�=\����TZ�� |@�U���yp\Q�m�wP�L�]r?7�x��moQP�����t_i��b�H��y��}�1�C;����Oe��l:�uU�GS�����*>�IN&O��`
�y0y�I�u��תL�$���ZI�d"��$o��!V_�$ĺ�N�k��2��}��k6�a�=�f/ �	2la�y�]�����gC����w�p\���Q6c)Dɘ1��!���n��if���]��	��.ϰ�9����2*'ῷ�>N�����i�[���줌���6&bD�(�1
�i��t��N�`����nv�P�߄�6[R
�%A6]R����̗sՒN�:���s'�o=�[6e���(6iH��(2m��	�����x���r�F;t�F���EX6s�9�c�S$\�Zf�����U��-�]D�(��?`�>�����B�(����Z���J��      X      xڋ���� � �      V     x�u��n�0D��SŐ�TBނ|�w݈��!��Ҿ����V��;F�<�� �P�{0ZCd����tѧ G��5N��'�'A8�hpOT��X�w�ԛ@�.&\����զ��B�p!�ol��~+��X ���Y�����"YƙCV[�
����hà8��3�����)��?\ʨ�@�E��2?A^�iھV�@^��&�M��M�`�m�8_�q��@uX#�n1�%����ޝ2C�ͧ�WZUo�&������K���� ~9�݆      R   �  xڕ��r�0���S��F��o��3
Qc[�l'��+�`�1�{�X����Y(��Ŷ ����-J(}���3�g�-ׂ)���-���\�u�ƭP
��{�|�b=c��A®j�pL{Ɠ��
��ؾ��J�����2���}�Cm^J{4�����0�,!a`�/'��j����Զr�( 8�d��]6C
z�I@�-;M�b��v8ð���)]}L�fI)JO(<��WY_.RA�2a�-f�����k04�����o�m��Y>�/8��b9&@'�H����85$w��=��X�����R�m����yq1�h*׶�� *J �<�؄S��,��$���|"�/�C	dyA\P@Ψc}������)� �o�E�41|�n"������Lyz{�WK�C����a�<Ji��sLI�l{2�k_�����VB��
sjz�~��@����lJ������$�*-�B,�ݿݾ[#�B�xo�Ifb(��	���y��*�\�K�W߬A����+�~/�0�-�d����B9�V��.W��7�����okl}0U�n���达:��w��.�z�	����L$3����/��b��<�E����"���1�/e�X�c�j��E,�t/�5���@Vt�ͭ)Q��z��?z����J�tmf�����i�Dq5�)o���w))��\��|��\����v�������      k      xڋ���� � �      `      xڋ���� � �      b      xڋ���� � �      d      xڋ���� � �      x      xڋ���� � �      t      xڋ���� � �      v      xڋ���� � �      j   P	  x�͝�n$7��=O���"EQT��y���1`'	v�￪r��l\,�`��a��5E��A՜���Fj� ���\���K���?�������/�����^r���?z{A��
��? ~t�#��{��~p�^>��}qLH�����>��/,�����Ͽ'9f>�{ġ���/}�D��)?^����������sw��>���_�g�7�� ��3|d��.�� ������=�x�.�� ��@v��c>��+���G��OC���/^�gY�/������5>ŗ+��n`}���]>�g
x~��%|��}���i�/i�����_���~ڿ?�o__~￶/�����^�|�y�1pgˬ<��Nv����l�QE�H�8j7t�I�	�����wbCǞ�S�� _��[�wr-���ד�Ⓧ����Y�t��.�s'�!�����XFg�'>�?�oA�VoZ���·p�E���)w��X��,�i�zag(�'~|:~�ı�����ėc\[a}�X�mX�������|UN�>Ŭ�ڨΎ�Q�-q��`��w�xMќ���
��	�H�g6�i�z��IM��R�zDJ���t>M��up�$����0�G.���u��{4����UA]8���{~=��G_�{�Ы]J����G��xJ�Ji�+�N�>���2���u�d�DL�¯�}d�/>u˩������O!d�:5��U��>�̯�:f=Tùӆ�z���N��ạ����*ѓ�BCA��X~�wA[�$�f�������{U�)�[xv�U�6Ŏ�]�u�N�V�PĬ�����J�ZH�]���sx6=BS8v��:�V�+�s�<_q#Ȭ�-�>��c7��б'~�q=�α�O�ȬT}Ï�l�R�,J��2:�,�,���7ߒ])��0��G�r�)��j�-J�ފ��l���C��j��;�B��K����$ä�=A�Tk��zz]L0<]���Ŵ���W%�!g�'��XL7u�=���>�j�_�G�m��[�s�/���^�	Б%��A��C&C�:����ʳ�s 1�i>߀^����4,��F/70�*�g��(_���ŵ@䎝e{z�&C��f���j��FO��^5T��2&�?��[Rˀ�b7,TX�����8�n�Kh�*?G˛j;?^ϯ��<&Ŵ�_�?֩K̯�j?�ͮj�����U�fT/vw��������t���M�5�ė_'i �P�ӓK�o���4��p��������J)���>;tK�����F+��ld\8AiL\u����!°��N�����߼�h�N���=�x	��z���>RMv�o�)���*Ƀ��a17�kb-�ߋ9�)ͅjf֐�#t���뿎��Xt('��{�p����l�Y����%o��.j={�܀^�|
g��K�f�r۫r�OEN���چ�h9��(JBg&���y�9KqȶW��lY�/��Sbے���D6| w|]�F�C�V�����{�^;Z\���-%�-�K�+��;v��a��?`V���M.��Ur,�(�Lگ�O]���m�G�����[,��0Jb�E�_|��J��/v��?!� _���5�܆��]�%��s(����>�7��I�Z�uB�θ��a{����h��t�U�e�X�f��������ւ]���x���3G���e�����;=E��*�ͪQ [����C���W�Hj�-���g���{TO��e�sS<��*6����R����~y�WF�4��?4�V࿙�fq.��p��z�'���5��^q�Qup��nq#,�bd��_%F����l���p{t�j�U(�k쉟�� _Uc����P�n�G=�_'E;�l�:��[�k�U��;�n�:��O�t���j��"���s;��k.O���E^��B��-��n!����i��R8�^�$�<}Ķ��X a������Q4���OA���,�v�Y�[ND'~�X_57��G��"]�?>�i�J��Ի������?�:IWs���|?�!�z-Lݲ�:��z|���-��O�%�5�*A۠�ⳅ�V�m�����U�|�Ȯ*���q\��+�]��R�%r�����b{�}T��+�M�T-�<���I�U�%�*I�$�b�_�G���u��8*.d�|�ȸ5�*Eײo�-��?,.?��WE��v��R�%��%�5�WI�Vzh������JMSkU|G���.� _5W��Ct��f��*���wQ�]��t��������7��>�L���*��>BR�Q����'h�],h��w|q����=��vO�y�O�_W���;`�w�$϶��a��Y�˖O:���|�[lŁ/�nd��@w�����������      i     xڭ�I�;����NQ�6�@�d��7����tצ��V�e(�s�OLs��/��
��_1����R�����+����� ���7Ɛ ���4f�?����/��&�?��r�|���;�9^G��LY��$��8�ML�q�rEL�zB�.T�;��K�A/��$8�0b��$�8x�8B�CuEܸ�sU {��1UYgf� Fq�qׁ�tnmL_ ��y�T�/�[�����\�\+�V0�^h�ӧ➛�x���#��l�1�8$��\1�ؘF�31g⽈W��^Ș�����G��	�q��i��`�#F�4�_��H,��[��d�W��)�+�=�V�.�������M�'�"��9qB#t&�sn5�ɏ�yi�t\�.�@iٚ�«8+���mzcP=!���ʫD����xf�⽕7+�q�1�*{o���(�y��H3��י]󪶨����L�qJ��{+/����({o%��`�h�pү �N"٣�RK����I�3�o��.֝���zoU�C�s�����Ƶ�^��Cs�����]OolGıX���T�^��Ǚx/�5*5� "�!xoy͚Ѕ�-A|������D� �VK�/��#��M����"ה0�3�3B����km��쑹��s=��:�e-�V�U�#��x���6V��L���1�E�VB�b�����t�tC�������;<y������#�J��S�]�XA�q�1-� ,��D!ة_�kL.�t���¹i4@o�
�K��_,zo�<E�F�V�^Z�4>wnBt<�e��#�2��[y�L�s�0�yo��Q�xA�4���Q]V^+��GCL_cӏxϻu�)�u�n�ě1��zA���m��l���bK��O]�'�����8.�y#V���[H��~Al�����b+�*������Q��[�xp�/�;JڍxϹ�c�q�d�6�J+�0���g_�x���H��8�t��{ C�X�Cq���^ި�� 1[�&�J�FM�����>�I<S�$���ω�2ZXn7��kG��[���*���E<(%u�y	D��O��+�܈��[�,���3wl?=��Э/>���"[uQE�xA�
��{+��q1#�³)}D܉��*j��}����=?��x�Z�^��oE�I\G��1���c��;Q:��KF�#|�;j_ļ�[H]vAR���<J�(��;o��0����#Jp&��6'q�|A<�[�#��qH!�N���˫��VC��EIT]t�ȩ�sb5`{�[��<H
CB���8�������.q�c�q7�~Al�Ei7�=#�q��n�-_1e,�37�x�Mɼm����x:�!��N�:�x�;�M�^���][��A��W�`h�*P-�����_]�[��~O[��L�i�Rj������[��g團�m\�\�
�9�xA,ӓ;��y�B�So�ؑx��{�Px;,��؋ 2�bFw��L�G.���;��H�����D����qUK�v��QNrA!��X~�{�B��(��ûM5R����y��
���E��?�����1	�M�N3{���[5I� ĔL����1i�x��)���cM��@ To�e�T8�sU A�7�$i�(�A.�1������gc?�=�rÀG�	����[���8C�3�^	B��� ��i?�8� �q���u&�nK(�'���<������D�M6�C�?�/BX�%ι&<'~fy�%V��<M	�2D����ֿ�s+�#�~A,���6��\�d[���M���˱�Iܔ.V^�yP�&��n���c�'ⱳ(�j�	�x>�fz���$.����$�p��z��m��o ŠY<7���^�R�f�U��6x��t>��֝����S$F}[��ĝ��o!�Z�Ėb?��3xD��R(��V�W���T禍�Y�PE4y��7�y���ظ��eV��X~C�Wǖ�3拲�Uk��1@<���Lbodm��%q��]T1�i?'�d�ݫ%"��>�����bx<+�C��<��kY�8&���u��ͼI��,���Z=l�LW�b����n�����K���c�Ƴ�d�sb�m����8r��+/$���|�)���D��Ə,�11>��x�w<�1ǯfJ)�R����%J#�_"OK�[�w����{6�,�9��nE�`Ari.6΂��#F����]�b��+r��UA�0��8'����%��%��)չ���lʛ��^�����q��c��Bq��tD\Y�C��%�<�d���LKo����TH0\TQi � N����}l�6��ν� ѧ�J}��T,U��q]���b��J�k�.US�:�y&$d���F��^�5f�#йw���PXj�I�:܆K�k�	�X�ݷ�%��G��qk�rN��M��?n�t�[y����/T���~8+,_�\�z�]������!�����|�����L�ڹ(��="V��b�Z������^Ut��)Brqn�O��M�p���{&�x�Ú���j]�%�x�a�/��TlO���+ �E�M��1-��K�G�H5�\�\�8�;���eى�21�qjb��J�?����L��օ����p\l�U�,���m�N�|�\W�^�Z���.�u91��6⫊�32�B����+tv���qķT9�K��jcl�[8���N���luz���� U����s_��۪�W����l,"�%�$&�J�M�����P���:K�������V��-' 7m�\��b�7o�$�ay�𦍣�W!�����`u�_U��]��sƯ]+���&q��m&�6nӽ�iI-��i��U���Br	��s)zL� ��vo?j����=�p��%���p��K� � m0�qҀGĶ���ll����DxO`͇�u�jQ�2V��[��+O��쌸�p��͏�T�6�4~7ԞJZ&9ϵ��~�4_B�+�.����Cl�eػĳfZ�85iu1��h��[+�w2ķYѨ��*9�X���DX3�~|�Cl��q�PE-.�9��L�o �w�q�B+bFY>��pwcIw�ϱo���I<�� �$~�(�#�\�������RZ�ъ�?w5Yx��[t���	���%���XO�y�g9���I����8�ӌ�!���� #����84�ɀO�m�f���ݓxc��!֬2s'�8U���2��>,g❃��i/� ��[�;�qa�!�9�詊��A���v�M)zo��U/ll��*6��������JR�H      f      x��\[w��q~��
�g[���o����$�8;�㗜�ӗjHp P�'�=� %R3!�GΜ�*R�n_5���׊2Jdv�0�X�Hj$P.,���[��v]�*�7�����-�QB�r������@��V�Sۦ��z���v㛫[,8��G`�b�w��N�+����_(��JV����W�%�˫�V9������?����Ǯ�{�ŕ�[W��k��m��U�����E|�E�y�"G-���N->~	*o�ꮆ��_l���p���:]�k�$���$�f���f�6�&�!e�#��'&AC�l�� D�i��X
Ɣ���y;�A	;t���w�����.���C�&M�A��6��P���~�OJ�L��+��7�>j����
���7�\.���Ё���ݳ�,�����u�b�����R;	J�>����A���r� �ۋ����]��K���DRW����w[�p͈̮���Q�<S#�ՈZ��n��ٯ|�'�48�z�&�qV�vp2�΀1<��w���Z������M\u��v}u��E>� ��A��|s�y��m�|7Ա���;h�vX!tU��R�j�m=�L�^J*!���H�=*2Ki�J3f��*z����ӮjW~��}i���]"2�T¤���̵X?W$_(�GET���X"l�f_%?��_�;��~����K	6([�[��"�Xc�G`��)3&̌�:_c���i����2Y�s�S�$�.ʨ�T��)�����̨�sl25�o������7~^�/��ǣK�!� �0�6}��:F��E�E��"-r�㝸]�����B��=4w�W���=���-������G=� ���Xi���d=WXF��D�r�P&)��sPjp|��$ｻ���o\E����ф� oatx�要z���Z�L�<i��VkOh[|�����Zv�}u��;x̠#q�ow�0/��)TO�V���6���؀f-.��_{�y��1���n�Ͳ<�P$x�ݹ9鐓�,>Y���n��OGb8&�e�ZdSw5&O���Z]S�D6�QG�X.��A���X�h���(����,9A����גj�&G�yV�Ag����)�9Gmr��NW��ᦍ������5���E��QJ�K�M�b=,>4M��j�ɴ$�^�װ螱i{� ? ��j�YcU�1�%�O�W^s���	�&��$��J��
l�c)c6Ȓ�g�e�hP93�2@��0�5'	D���`���en���T�8CLwH3GZ�F����C�+��Xڛ��Q�u��C�G��o���Ň;�*z����� ��$$Y������j!�L��-��xM���ܤd!0lt�N-0 ��RJ��o��`d,�����H&��2A�jyn��5`�� �+�Y�.g��4R��V��k*L6wX�������'99����{��R�g�}�����������y����]Zb�p���:b�����3�L�`c��^\���ɫ 4�6G�sb&��+_��j�:=6U���,9<��E��I�Z��4�j�n���6�0�'���R��T�R�ν�҈�u�xlf��uTa�\���Z�mvc�lK�:F44�tT _)�Q�����_��i��C>�9c\VրL�o�*!�:���)�/]�Ǽ�,\�et,ǿ��ak����`�t�5\�_7H�ޗxCJ�|��n7�=�%����Q�<i�g������P�Ep�š�~����a;��=��m������
ù;�G,\��f����X�����'m��Bj0Ԅh��)g�E�>�A+�Y��E�!��AD��N�i�dX;�(?o�,�6Q?g k`�5p�(,��h�ʆH�F:F�vxE60{���1�Or���n?���k�uu��rݬ��?��L�kV�����,�6K؈E,�X�it&Rp1G��$l8Nrl<NS���~�� (R������9���3[�l�;?�Z��Ll|aQ?���ϓ�<܁���;���u!��K��A��֑�m�ͮ&����23Q�G)�b�N�u�&���H��kw�B����R��ґ��?���J��@�ڷա��t�1A�U��ږ�M����C��SH� n�f&S�	��$�Np*�a�1�B9Z����c(�[�律�v��j>�t�#�z�}h�*-��wK@J�t�-,�Ӯ��c��0����_	S��E���Ua��#>5T�ݟwHB1�kʳ6.�H2=L,)&��:��Jm��O�d�,zIY�)�l)����]a"P�M��H��v��Z%?ˣ2(?G&�an�ӻv���/��К��~(4������� '9i�o�.��[��P�}.d�X���fh�BN-���� �!g���I''�V`�X�����M4s���j��9)I}�B��njN5z
�"}FY_�e����#zy97/~Zo��?��B�zڑ�m���T����T��_�U��̠�
�B�n�N���G��Z7ô��?Scb�<�*X�ݺF�g���d{�p��/���1����
g�b�fܴ��}���<!CMu*M��h��!�J�^^	j�4XB2~�e��r�oG�|����������v]6$�WH�a��r�:���ˋ��>�v�8�t|||��x|ay�����ȗ]����T����pE�rE��}Z���ݸ�Z�,���[^�l�c�Pn�4hڪXn�-�����n�:H�w�$2�|͝eT�|T�R�D�nJ�VA��</�t�%l93<o�Қ��4P̩�b���μO`�荼��$��d��u���N#��V��O�z�}u|���\gԕa��!����)D�.#���<Ec��K�@���؞ �����a�ӓ�R��;>G�r��fRh�N�s�33�o[��#x�<�O���u�=�uTg	��R���X�3�{�$�AR�)��ߡ{&�PÄcP6�d�r +. *���Aj�;!��zQ1"*H����eD7�pB���?>�G�o����RȪ8}%| ���SIP��h��R��\�Ϛp��GDS(��.UP���LL"��g��D6�g�GV��J��z����>����J����1yD�T�p��^R儍����a2M�2�6��0�{��PUW�36�WQ*�PO���ݷ��"��0���Ud98��	�M{��y>8�>�s,Ǵ���;f��JD+�t*�O�� ��T�Xα2l�B6EB�*.@�������J\�Ѿ	���p�o��(�
�z� cM��߬_Y����Y�EO.���O�ڄ|ؿv��p�-��߼v���3���Ժ�P�S�r���w�n{Z�%]����_�n3�n=��R�N��9g^opwZ�#��W��մ�ťa�)�d��~�ug+(�rݜ>��S�[v�y��S���X�ܵʥW6F���%ga��,$PJ�A� �*�/L�(�Au��,��N�\j}H��w� �4g�5��d�3���Z�~�d_�(A����T�Ϧ�^�W�2��L|����'�[~+W����H~�(R�&A�F
�p�W� q7����O$#w�	���cNȦõRI%f [�d|�RY����L�d(/��U�2�?��aZl��������ɺ�B��d����/
�3��ѷ$'�eǖ�x�,���2h�)*��y2�Z���'B"aV[��Q�QT2�Z�2t�.f�W����Ԋ7ӹסg9���)�O
���~xc�z�@y6<CǦ.�l�Y��:;����V��d��fZ�z�a���b}��O�������C�Dz,���~��;5�c{'%���N�+́����:u��{/x�Iz� H5�9��?����]h��EH'���x}�?A��ܗH�5���(���S|�� >~����TrO�'�o������"�Ѱ�U� @Y��ؖ
f�1󐵉>M��Ӿ�1Z�dךY)ߜg��|�] �h�3&�G�����irR"��W&�o>/�GLW���l�|҄��	'������0n'��#n&/Qsĳ�~�������'�S�ܬ���cT&��K�JN�S;=�Z2laO�]���[��ęl.�זxf�'�ݯ �  -�� Ov��w�k	}v�@�wY�%Z��	X�b	�S<���GQc?昖�A���5�Rq�M�Й�$��=�L���LYYi�L2�s�uo0�{�i�[����eZ9���JZ��c�BN+|T�rV$��Ӝ�Ϥ7��N�r��Lˁ�i�Z$a�L��so��������V�]�~�GC�6�8�;�����]�g�/LF>�������0�m��qHzUӳon�������߼o7�L�u�8]�O�Ȅ��S��8���=�Jku�!��LG��Y�hD�Q$%�2����q�H������F����3��;1ssRG�
Q�3M���A��G��)��;���M`Wk��O�L�<i�կ?�Ms�V�}�gLƱI4��LT�T~�/�_U?�C?��k�t6���f��aUm[���8B9�UN�س�����"�c뒥����,�����hH !-� �{��� �D����b�h�*-؋������	`�%��>�z��7��8����iR�����l��_�2o�n��K��z��lm9#���q.�1�ɟBJNcXH�E�D	HY@,h�xE�)〝f�K�������S�r��~{�䔂��۪���V!9�2$v�����#m�*�K�Br�����χ��;
��!4�lV��8������_��ʱl��.�_1�̥�\�L#��0��H��F$�݉�����t�Jpg'M�0��7�@p$�t� if^��ǡ�g�jO�����s�����dn�f���m�j�����qz�L�n�q2�?`6̄�*��X�����ye>΄C-ؠm�Zz�--%����0Y���ͩ2�����0�+3/��i�&k	J�8�c��̐�C~]Ɵ'��^áj/���Y2:)���r�m�=����X��T5�G���ŵcV�O!�R��� ���t���ôC�6=_��@�Q��:�a��ʹ9L��,(~S
't�*���gIc���mqY\��l�j�&O%�g�(G� �*��d������L��'&�v��S�Ю��x�I��T���1+`����A�399ɉ�-ua��:#_o+d�% ������v8��2>ҝ��I��zK�	�z i��n��֕\+��3���;m�v�JdcY������k�����ϔ�������I��b[�C�^�� &gbr�ۇ��ŏ~���i\B_N�]�R|qŚJF'�[��w��#fƸ~��@6���A3��/���s-���H�n׬��H��㹯z�]*��wT��.�����w?�L��M��"�}0�_������"��?�z��'rR!�.�y9��ޣ_��������n��-�v��̕,\jb�� }�������~/f�$"K�r����Ñ����Mn�R����(}<��LJ���$E���,v���C�ˁn$P�Т�M���k�x��K�Sf�ʁ�Cv�Jxe=
�Hʽ<�+�EC��&>`�@m�Ju�
�q15�s�����}�̙�$,&ᙓ���h��g�U��3���
��q�P<}��X��f�ո%u�<GQ`�������ɖ�#���%�l �K,8Í.D�xΐAk�.�h��-�g����]V�|wB��J�q�yP��?A����i"�{������[�={��c�]֔*]�4��a����b *�J,!L ,��YqŞ6fi�23�RW�Q�^�<J5������?�\'      g   5  x�ՑQK�0���_��&i���	��胯s��rW�d�f�!��&m���?�ڞ�����Z��V1{�z��_%/�/�f�x�7��e�PR��_��y��`Hr�������p��cZ��[R��s���9�U�HM�\�O���ܺ�!j��s[�j7[t8je�ܝG�Ѯ*��>EE=��@Qv�Nl.s6�@�ڴw3Z�y9m����g�Mz����o,���}�w$����<�A�˭iM�]�i�"�s��ш�2��$���mc�(%H�H��Y&��so4� 1�\%��ŏ,{�Ͳ�9Q      h   L  x�՜Mo�7���g�7�R�q��a��
����I�9N�`�w�?Y��KȤ�d	� ?�I�7�ذGؗ5x��wY�Z��r���o������鈧�q�����/�w����B�7���f��������1�r%'y�\�r�=f����/|��}�<}H?�|H?�O�����:B1<p������Y����j����9��2�%<�(�P�
��UGa]�u�:΂���:�(]��u�26v��x~��SJ�u<�i��*�u�R�$�rԊNu��ٵ��B:e�M��h!�Zey�s�D��RNJũ�6B*}�gq�J�0��U���]�9�RB^��!+3Ǚ�m��RV^�UG����q��Sr^���p��vuչ&�����ծ��$y�WGe!�r�1����Z��خ�PY$�������FC�T<����*%BK^u4�
�Y��*P)'5�v�H�j���<����Q�%�UGajmK:�1Օ{W)�f�v�D��x�s�,�A��	��Ga�=�����{�H0��#�g�����8�ĒH���h#�iSұ�3��"6T)ak�W����ߦ�U�C�ܴ��R;PO�u��H8S��w��?~����������������<d��9���V�/a��|�}+����I�;~J�o�t������v�&��]�N�A~9\�F�oz?�ǻs��y��w�U��)[Ѭ3H��4d�nR+��\ǖb�6�g+��.?5��l�s�9ۨ�@�� NW􌄂 ��o~�N)+�W-����<G�=e Q)��u�m�#��y<��fN������h"\aT��T)[�ū��Qk	�o�͑;��ͨ�i�:m�3��9|c4��nJz�)�b��]�z�R�^���Wt��RԼ ����UG�u%��#�T.�?PRx�r��
#,��a
'���FɄ^Wm�5e�a8eY�5ۍzum��q)�u�)�ju%���6�U���I���Vgm�s������B��&7�`��҇o���T��\�k��J	E^}��AmU���yB�X(%��b���R�*qF�}%&B�r��j���BϑŚ+t�R��/nPCU�!9���5ʞ�8]�02��u�H�h���W-�����}*���P�`�!����Y�^W�)[󫣅���<��"�ڍ���;F�6Cu���*���ڣ�B���h"($���14Q)G�����9z^j �?ּr�Q�W�D�B\��UX!5��)!�9�h",�f��c�-k��7JI˫]5�̞�s0��U�W-����r��p���UJ��t��FXRe��\b�Y����MDa�#Rv�����Ss4ʔ���h"�髋��� �.bk      n      x�Խے�H�&|��)p�[��|�;I%��S*i$u�ڬn@�D'I�	R,�ӯ� �l�L¨4r�v�FJ��3"���"�mb���MQ�-l��<���b?��F���,���o��������������(��,��}�^�;oi�v���k�ߵ���u����;t�{�Z�ue�ve��n�������YGU���o �M������Me�G?(���o���E�đ1�%�(CP��G�ݵ�~i�^m��k����z�E��ޮ��݂"��̺�̲[��/��������]�[�>����~��J��N�s콺m����{��۶����������ۮ�)��]���fk��������7��:�������ү��_b��V�E����V��;���1Ko�}�+|�n��Op����ΣXw���7��������i�}�߻����VfM'�?��v~�Oշ�u��g�y��~�[�Ko�-[�)}���f<���n����G_���~���om���H����ңhl�5}��v�o�b�5��������<h��79�E�7�G2��x�=M�Џq$��ǥ�p
)$���mM�vE��s��+���`��{������vK���y��U���-�3A��%�������E���:��m�_Sh��o{ST���uۓ�/����f��m<{iwKG�o).t�{�Xϴ�;�]�S [:���7`e��v�ף�(`��ӟ�rͻ���~���0kjo�n�ӻY������I/�bz�.ú	�	1,�0B��k*<�UGw��vo�W��ځ�?��|k嵨mej:�[zTj<���n���R��.qX��=?Jy|���{zq^�.Wt�̷#3����b�_�]��{<����͒��n/vx�"I&���Ò�ޭ��NĚʐ�q�6^E���%C�z��]�(��͒�������h��R�~5!Hi�s��٫n�1��'W����.z�6�w�o��fg<S��r)Uت���o�T��ޢ�ݲ$��������%"U�>�]�}��{.�P4y�
�"
E-=T�]�-�G;�R��~�\I����ߟ(�6a�_YI�Q�N�S�)��>��a����o��NT+Q�W���(�X��͊�N�ET]Y)�ڤ<����0.
I0{��K��˖j�u�G�֜��z��'������ 5�o*�{$7j�"��K��4����)����<�K
�ٯ�q�^Iq��׆r�@(6����޶�J�.z������������¾�&MS�5��P�n��ϋ<;?��a�\�\Я�R�M5 ��Pg�bS���"��	uX���x��:T�3+�6�m6���KCg��T�
`O�
����;�mw��|�}��[jD�K�J�=��t��nE�[.�1�y��bO���z�-��˂ �}m����ޡr��`��{��;����RZ�+�]�-��ш�@�� �}��)�[������{n����F�2�從[|�n/�\���vO��/�4�G�HgtN6�n�B�Mn 5V�)&��8O��#���P�C8�5u�sD��L���Tt�~A�^��{����[�7���F{g�V�󞶋E�.�t­L�<�h���m�?=z���U\S�:On����ۢ>oڵ��t�>���l�z���C��w�K����>q��+ɖ��˖+�m��	�2�g1�U�	�S�ڝ�5Tn��{5�ܴk�ǞǍ8���CQ�y+ƺ;.��P���̯�m��22��43�����d�p���5��T�-q}{���"�~�浫M������X���徭̮�A�q�^�����Y��i��.)�7�c1˃�2bF�?�M�Wh�����R��%U�T��K�����o�3�Ƣ$�0:}bxJ?�.k�	G*J�4���/]���C���T�=��L���O�vy��k�O�%�vM}�|��
�x��\�a�m��k>N����q��Q��4��'Et����y�l�_�����;"�s����7�u��n�e�#��^r�r�|���a:�p�)�����l�<���/y���&M˰c1ն�{���d��f�T����Ӻ�e��e���<�_w;���-���g8Xy�f7욨��/�Ѽ�~Y�Wv��*J��z�1Us���?[�d����s"5mO�i`I���8n<0D�kW���
Vt��Wz/=��i->�K�.�~^<�8�/O�&q8!���2����H�hOw�:Q����a�y���ZﯻE5���q�E����2m)�c��Џ��v�j�6�mN
�W�b�TZ�ily����#�V��̑��,���,��d6��^�]�ykk���ƻ>�~)Z�J���=��_0M^.FuP��4̣Hf�tHt����������l�}�`V��׮wݝ�[�m�5�V����m�?��?����٪�&�,S��Ԏ�T�k�����B�RG�;�ѓ��{w���Q�*Hc��F����.V�ڲ	'��Y��F-��mї?��Q$�k�+B׉��Ѓ�
�I�dAǏj�\?n .x�.�!�"�'\Ռ�Y��M��F��O�4����РƧF��|�/[�cD��J��v%f���&�2�uC��WYd�>�j'��<N�@����**�"[��?,:�\2V╥&�jx��~�X�h���,�	*|?�t�/��XE�,��0�@��J������V�^ͦ��-�E�u��5Մ�E%�,Jf_�՚�-e*G�%f�ۃ���Wpw�WY��n#7gh�m�YH��ޮ���rs�)wkZƔ��4%5zO{�JK���j�yl�R�,��fD5o�����~*P�p�n�Y�?��N�a�Z��:z�P�2pM�b1��h��������"�H���,�	�J}�F�T�����K^.�̮�����K��-��ݓ�a�����X#إ)��iغg�i�<��E&�Tq2�)�9�mtf��:�P����0uMMy�S-L�vI�o���{^�,��\>�۪ ��Ǟ�*�����ZeUd�i�dM��93&� �˒ N3�w��M�}^1�g@+kw��С�i���J^�t�u���_뜭�o��[a�J��F�,�dk��� Ċ�o�t� ���v��N�h|鯩�$������yn�_��j<,5/��8���p$�VS�k�:�����k�R_��%��Vz��r�'�Z @{�{Q<_4u� ������n%�/=�h��}���B��Ś�1$��N�>��#��E&#��t:J���ߖg��+��bKFx7�,1-n�'�!6�IL���eRn���B&�ԡ?���!�v`�\JP,(n�@&�����,��S�,S1�㾭]�\���S}��3d��}��
Y���~�`tt�(��/���'�iY�����ױ:��S[��)��1 {������N;
z��F�� #����J(�`P��V��8���Ɇ�Z������'���X`������s��be��x����x�h�ź[v��XY�(���^W�Qj����ţQ��ĵ��l8�u?���-^.��11�L��La�*���o�o�ST��Y���`��D�Yep��@�{��}�[����p�r?�C1��[�ҒV��-9�-6��%��\�h�(�.�˽�MT�� �q��(�c[1�Z�"�;R�d1��G7RY3���8qX�����k?�P���D:,����)i�q�0�u���sz�ˋ��nM�9]>�o*�Bf�2`��'@ӳ�>w����F��^0�<f����1�Jew�>���<N;�����A��!��%���KdF����Ϝ �0�& �r?̲\gi/�󽕆��Eq�����&D���?�y�Xt�$��D'OB�}�U�^��f��*�c�����dau�w���,�� *�P������w��Q=���!be���w)|�Y�8�5V�E��76!HE�<�� ��I������y�H�C����f��H�v�<9 �OJ������)EC�(8�
���B�����&+J�$��� u���>H��j�u8�����득�=��Q�R�I��Q������A�x���    ���L��)���=z��vT�4�硸��_����y���֖z/�vV��=P����}�q���Cз��qh��Q��D!���T�f��[C���з@�uNˣ�eEm�QQ��Wx�)�-cü56�\����I�3����m�}��4��L���M�"�(��4���̀����_��v���E�G������u�(��fB�� �ECӁ'�h{+ ��c�E�,��Ú�}�������$��������= ���+�t��� �O��-ST���0pűmמ�d����o��'zkO��Z:X���::�����a]���]��J�Uz���zn8e��<
4N�j�ֹ~�,q����v�W� �ҽ���u莚�oL��(��׊Ϥ�rX���C�wE_m~䗠�o�����PP�Y=�8@K_rz~-/���&B����H�Uv����*�p�����h��>cwL��9>0V����gk�l����o����"n�T.O���R1���dP��U8*�U����<�I�9f�(&{��ߺ%%��*W��[�,J�x>�m��m���I�m&�1U]p�|>�o���y�ďVow���ۺ���llr~'��I*���:a�02�'y\��TP@�v�vI��˖��;�n� }�����,�̈��K�0��"�@m^5�24�L�	��k{�K*�c�Sؖ]w�g`}��#�@z$�0�8�7P��֟���gYK�����/�۸��ȍ��6Ė Ir�]^����t\��n�����g��>@��Q�P$�������2�Ŏ��ڂA!�؆�X�߰hS�o�N�Ӣs�Kؘh�9ϋ��g,�KH���	���>���+�㮱�j�?��??��WT��G�;|ӳc�q�Ú	����I�Ẃ��؞5)dk�fۊ��\Xl����f�����gE��Ț<I&`�8U�c�Fu)���՞�4 /��}��Ӆ�ai�G?��$�&����S��y�Po,7��)T+�W���l�MW�濓=�'˫�J ]n��#��c�(F�i����/.���"ɳP�n�v�h0m$���������Ö[cg�_w�%v=5���F�������W��HC��E
|�7�Ɯ���E7�v� �.x�.w+��P�=����Ru �s�"u�r����"[�s ���ϮT��X�^�.��3�-'(�Yf�8{EQگ1���6Gca��)&jA�o��`mZ�@�c%>j�w���Dqax�#��i�(�}'�*��H�<��B`F/d�%�n�%��̲�<�!+�8���i�n#@�����e�P��̤քŔHfq�
tx݀'��m�ܹ�%U_���[�HO�1ҳ�_uVc�`s�	���(����*����̲�<��c9�0������M�.��y�㙟�2�³e=PĮ�f�WV�N�P(iN@Y )T��t�gZ��!�꒕E�G�E"�Y�O�T�e� �S����N�XCՠK�4X����+f�Pb]����7ʡ|H�z����n��R �$�S��8�-/F��6t ��,`Ne�##�yB��YW�}5�ڷ���
�DйA<��E��yZP��H�uߎM�B�� �IOުc��׃>5���9H�0�����A$�hǀ����A���bU� ~�<���7k,���5|�!�� ?xC8��X_+}��o,�q�*�&svkT�A}�v��h�yoQ�	������	-˷?@�\�
^,�eMx���U��d����������u���dN�����@Q���|��NZ~�D�E��a�-�N�*C�����mQq�8�7�T�REIU���}��umn�~(Wwɲ�b�}ZE���>|��t^jW�[�{�%`��v޲8Rh	����O;0���̖gO*�<�bD HK���{����jz�Wc���c\�Jߗ@�M��<w
,?��$���	
�G�	Q�r�
�;΀��v(h����?��-�\�L�6ޝ4N����/��s`"����r�9U�3(O��u���ք���!�2S�~ ;�䩻��,��
�i&� ;p$*)�.���F��:B�qT@�C��u���Q̈́�e�0��p�A�+������Z̯;�H5�k]x� R�#m��xm�֧=�ܐ ���hWTcx����v���I���C�GY�*��W�U	�<"�+�������+F���̞��r��@�Nw�l(��bf�	 �ƨ|�Z�-���y/��ڳT��BM������������� ���F1��Y6�U��Bw.)�\+���q#��9Q��D�c�9
��Գ��������ν�F����J_�agU'��Pʢ�����ψ��
�n�Q�eG	ZE�0
'm<`6[�ݦ9��wӆa�N8Ȕ�s�yhEC�" ���P�Ul��B�i7��n�:��e���8P����,�mc�w��ս'Lf��	k+G�l $������U�ˬX&�Cn��x���Θ5US���R{���a:��.��� �Uqßcm�]:V󠌧|�Q��{��0`caP.�eR�����Uv'�o�RN��
H����G]�C��5��H@�)��μa�C1WB��I"��r�G�
�<:?��_���
s��@I���k'*{��@�M�z����e�UH5��j�����{�tf���8;/(�ȰkÓ��g����s���9�:����9S�����>�;O6���dXA��b���Y+��(�����u��D!D�&
P��@���Ƒ�:�ѧYX|��;�����@n�LF�^���{�[��+�c�[�"K���-z.VeVa\�� PIX�~�_����"yR����+�^��8��r5h�D��umueS�_�E�����G�)֟a)G��
̍(����*��>����<������HpD���	�_觾�2����
hف�Q�|І���
��H��f[
#=*;N��ǔ";���YzJ�(�%d��%�����Нb������}�V#���!w���wl��X*�0�b���l�ˢ/�f��˸Vlnz�Y�r,G��x���~��oj�D�^���wݽ�w�Z������E�AzUt�=�V	���͜��ݞ�lu�/��F���� ٺ�G#>�{�k�3��:��	3�0��Ho�4}���a��R	�g�%#��сs����I�q`���:-�G�,��ϣGcf�9f��R��^�p�k�������}x�7��
*J�5k?Ŧ� ���{.��ѣ��2�+�hJ�r_'��8>ܠ ��>!O\aR�ܙ�~Dh^2:Y��"ѩ�8�'D'd��>��c	|W[2�q�E
2���O��y��V'yv�?,�,UO�7�����{�h�kk�;��6�t�����,KΏH�S�Z
��ѯ�1��4o�����e;�Q�]�.��om~��v^�xwzB�C����ڎ�T�u�i�Ψ.L~�P|`����])��ۉ3}Mf ��}v������BSf27h�؀JH�62h�n��U�he%^``B�����z(]9v�٘z\�Q��2s��t�︨����9f�"�0�.����3s���&�'�<�Q6{��5e��~��G0��u6D�������V��f������U���FEA;���r��:]^��x~N�<�p��'*<󱱡M�Ga�d�Sz�]x��A������2���	rٰQ�ܳ�Hm�Z �g�:�gΔ6�����!�F�0�}����Cn�P=,�`����:_�N�s4���d���ČG6L��.Y�^,����	�6ʜ����x}�`$����ƞB��qp�-��6��dGq0 1�U�V�7�Da'�I4�"�=����]e��*�'��8/T�)�����'d#�'X���b��5��|Ț��� �{ɇ�b����	�(��ā{�9g:��d���X���
:���>��@5��^J��r�Xωw�X�+f��/��	�=wP�l��"J}�8Lf,��RV�    Y-TxY��yl��4o�UawI8���[��}:���
�`���3�0l��<�&�b�ә��)Ri�k�\���8v*�(�h�"f"�l
Fר��tW�"��<���L��[�� ��[�R�M�i`���(7����Z�Z�?4f��[Z4E:�lei< _Qi[k_Nڠ�M�cd���0����"K7�U�CA�w���s���q9![�Ǌ�e�d
��b��0g�郂���s��G�|epQP�C��5��mi
3��
I����>duͺ�L_:K��J�6t�a8R�X�cQ� �EG�*��V@/�����
y �����+�L�8�E�'����k`(��T7�ÿ���(�ئ�-*�g����_�v+��=��~\ʯK��A� l*�3����Ñ�������'r�"vd  T������;�	�eP�td�y�K��"�7!C�a0:1=c5YK�Q��>n$�x�=�ʹK�{N�umV|jQVcɻG���$�Vƺ��� 5�}aG<��`8gn�B3
��Ϛ�S��?]��W �<�u?	�\CW����(�3UMP?fx֤`���(��B�������WL}��.���1{t�V�"�QT��[�lO��gS��Og���EMP��p��*F��݁o�Ë	߇ǀNtWn&�ش�]=-��q˒,�H|�0��ħ��:���Jg4��1N���éR&�εN@=:NM����hOL?��"��	�6K�F��=�@q&x��VH�*X
Z����a�+0P��&u���2��Ο��y�vl���ή���L��z���E����a��h����I2 ��2���g�q�BI��N��:�g>c�u���9��'[�u��1V�ϋ����*4��X%i���G&@́�Bi�5Uk�)��z�*��ƄA��%���~��{ ��V� �,�C�/��4=��=��O*��$)�B�X_��L��ET�w��v��+����2��ע�;��1=	�i����c�z,�64�c��� '�7|���p����\:����������dX��:b�/*ڙ]1:s�����1�����j�[�^U-=N��Q��:�N��z�E`q	n�G�7�+,d����93�pM�<1�iT�	m�::�YK駶�B�Q� 70dF�[���/�+�����vZ��Ġ�E�^$h&��	 ��4�BO�J�9�f���R�f�8h��v�2� �+k`vDUT9��WC>� �Ԙ=w ����@��2���?����I9�̑���d�� f}��@0���w�V�h�1��X�%x������%c{��]�S6�2��f�8מ�-`���S��szz}���O�LhMv���qd̄�di������$�(�l�y����SB���̧�A>���a��#� J��X�Ӧ�Lʐbj���N�
���1�2��-2��XG�9#QH�y��-����85vq��s���K��FH��V���~_m{/�̨0T��D�P�
h�Sv��ؚ>�������3�J��ô\�e�l`8�n0,
�v]{3|Q0J�:D>�W�OyE�)��qt����*ph_�Ћ����X���N��sn>��2�d���91�i'�r��	�	��4(
ѐ����9�V8�"n����ȟ�͏P��e�����R6�BNN������d=}�K�Qݜ_�Aa6�v�^P���kV���5���S>�ɬ���R��gXQ�L�ځm�F��%��n/0P�??�
C�?ѱ<*d~>���='O�������택���4k�G?(���T��cS��4Yt������D9=��W�g,���{�!F��돇�fK�Z1IJ��m�}��F�,? ;��ؿ�5�Oha��\$�Uq�N;���H[�)�q�,c�ew��B��y����j����V�w�a�zM��uo�J�ֈ��=�~L!=w\�"�@�͂8I� �oؑ�[Ԗ��Ҹ��.b���?��>(�O�61�P>�H��-R�L�\�����Z?�eq��[qo��7�|���g'茶�n �������#���̢s!8=��o;��Z��̠�]������}+"�I���T0r���<�t` �e��b����0�`�9�t���n��� Qp���ߪȁ�mVv���Q�e}߻��`4���Û���$�vxme�O����HF��L�Y���+v)u�W꘲PW�ʰؑ��.��Gwi�<݃.����W0~�#d'���	�����5��@e��L,���a���:��4)� �㧸˖̑��f��X�Ag�F L��h: ��L���G�?�/N�ș5�g�c��FFD���]�W��n��d5+�Jy-};�:�ʷ�WJ��f��;O��<�S�$f��w�a�|�3Ѱ{b����g���VQ����^��H�{�;O��=s�´,&�/�,��-}深oF(%
^�_&g:��X��Y��;�U���+�1�����I����z,�MX��M5aP���"�Uyz�h'˃4-�ً5��w;��q�� F� Ŭ�{��Ӄ��I'�i�4�/��L'�*ey���Ԍ\� 9�Q{�QsŅ�a����O���V"O<C�c��ƨ(L:��*�X�����E��O&P\�2���O��{�x�����̊"ʹ�pf�������I�R���a�ݳ�<Y�H9r�xa�V�dr1gb^"�a+�7�o��i8j�8�g|���f8�|��+���wvI^1~	�Z&��dPM�����5/�P�D�s@S�����xGtK	A�&�J��ն�{:6��l�Y��D�PƯ��9?�A,w�f����2�Ĭ֔���h�YE�6��'�K�#����O��^���:����"pI�[
�CY�{؇+����S�zP�\�CX�Yy~Y�������D��'0ņ��Wlk�wR��0��q�t�穮L|�˘��/,�|�J�]۶�wX��_�A3;�4N�aH
��n� ��d�[[sY&�˵ӏ�n �KQ��Www��HMZo<1V��]$V��&�0�Q�Ɓ�?{K��̋NP����,���.R��Pf~`u��Ru}�g�hm��l�>��T����!��B�+˗	��<��`�����;�|��(W |���qc0��$�}|ϵ##�!�(�k��c2������Gx`u�/4Sk�$̃B9�_-��m�3u�;�WQ�W��0:W�6�G1���P~�cw��>��L(�\pdA<�d��;c;��k�-�t9?@��G^�� /@�V\@�n��[>Zmc ]*��`s.ⲣ�s�"�{��NN�|5��od��~։(��_\��ڢ��!z�?v?�(����>l�k�o������q�U��ѱOU	4�W�9�ٍ��P�?�o�a�Q�"?�-��]�k��4ٟ뿟��%tγ���En��P� �쎼�x�ο���rc����Z��O�	e.{tp���!9�N��N���#�?�Kʦ|l���u]>�ܷ�};�UƟ0�(�<HD�W�m�}>e����fʭ�@�jƢ��dS��OYa�GE@�2
}~~iR�I�+��M������d��/�)
����'m�����&oίa�(J$������ÌLac(8 %b�N
����m�{�OX��{
������Rfk��f�0Xf��;�,W���w�!V����n�Ԛ���K�`�sj�ظ����QaH���2x�ߝ���v��K�4��˜�}�m��d�F4b���QW�%��W^Bz���l��rE��-����C��v� j�-<.����V;���ak4d��^���
l��>m���W�i�j�y.�P	},�,�kD�l�d����i�H\�����2�$$����9-���,����T�N�+�$�t�&:�v�����5=�$;=_�]���<͜��ofZ��"A
lM�J��ȕϧ��>�B���	�_>Ko�DaTLE��z�g/�v�g��Dʰ�(���eY풍y�3�R�x4e�����j1-4���ⲟ��/�    �$����"�Wn��.Eu��l��G��v0�]���3� ��G�f���F�9A)=4l7X��=6FN��ȒF��t��c�&�zh��k	ݥ(�ŉ���.)�r ����7ǫ����¶в>����v ب$�b�0YׂP�}��`�7q0q.i����V Ki�gd�/�ǵ
�Z˥�� #OP@�g��7��7M��{�aA5�Na�8��5���&~~��2���*�pp�"�ا��s� �]�x�Ux1�}����OvϦrʵ���щ��4)���qO��£�䦡��(9	��lQ0
k���J���O��-nZ���-A�!9��\K����g*��N��AOw���QW	Zd��IA+�1nI�H�.�9�=��?��^���As�Ó���Lo�CV�+\<{#��A�k��J.�P��NQ���a�� -�ͰY�1��D}�x��>���0L�J��;1�0"�\U5@]� ��u[�fSGFO���)�О�"���MgC�U}'��έ�K��~.4�Q9e���iP���E�SՄd��=���rbc�|��Y�J�jR�=h��j�a��ǂ��V(��;�ȸ�t�8��9����Jx�^Lܼ?oK�����B�T�v������]7p2�σgJ˵�
���P�a�Fu��j���	�c�X���c	���Ojk��>(��y��� y���&����8ס�gh���T.�\�Ǥ5��j�쎨�~�I���d��$��'ƨ(���H��<*ο�T��y�S��o%6�nUE�����)��g?#u�.}D�K�􊭬�5�kʞ��,�nӑ7t!��v�ڂj,����F)���"Qj�(�p��<�r��ޝƇ�69�1�S7���$\�s�̏r��$��GK!�Ts���^�򚿲��i{gd�`2����܇%2k'D%�ǒ�>*���!2^S�W������5xs��n|���w�4K�}�U���n�@iQ���6����
 ��7w���!�����NN������9�m�+���H��>N�KX���(X�/��l7q���g��V2Q��>��	ԕe���0�w���M�G��Нl� �g�]7�I��w޻�`�鐍HjN�]d��j�η�hb���h�:��no����"���ֳ_��̧�,�r�i�6`���_��V`l��@X�)��g���M%��Q��h���\�'��9���]��ZG�����o{u0ԁ���o���~��$�E��c��� �����d<}<jv4�?����r��Ǖ�'xط	Qj���G��CW��c��'�.Ctv�"?	�"���x�fp�=�pa��0��WF�?d�X����nײC9���)/�FCG^~��L�=�E����rQ�f�e�nP��uJzr߫� ��@=ѝ�$���\c����)�C����h��=@��t|ʺ�7l��"�����f�ի(�wH���G��C�8z� *�c��ܘ�#���c"0�:F5b��EE�-Mx9�+�y����M�Uǘ���0��C!:_L�Vx�U��MT�I����z<-2(U�;�=��\ �v pS����q��\�*c��8ְ����"���b'�����%Fe� �}'�B��8b��|Jr�� ג��V�������:�Q`[G�SV�=��i| &�ʙPV7Ep��6��\Z� �s��vC�Q��d��K�M�`���
a��l��%�[�K�3+��0�$V	�T!���#��	͓���]��,� �ν)F�vN/ȿ���i�HCUF��z8���M����#Y��0�$�R����;��m�U�J���9�����C�)��"Ȓ:~��	�,0�~������$IcϟP&���Lq���O������h�Q�ۧ���sʾ����.'�LlRs��b�g�JI}V0]�{A��]Ai���H��
����9p;x��7����	A
��FÈwiy�5 �b�57 ��ڂe�TOmbej��������,���H���&ܲ0�݀S��;�:)7YI�=@#�XT+Rqi�R�����`~�SQ�*�2:V:�����ފL����1�d�$1�߲� {z��ώ)<�r�gz³*�ͲE��d/��u�r���Q�S̖2(����z�C�VOh^����G���
�>�kX��BA�?��� ��7`V���A�ი�i��ʬ,���ԑ�~Q~r����ƠC��	�XE�t`�������#^2�߽��~���8�Q�1@�}�q-��q"c"v�`�'Ә<?��H"z'u��aIG����+�OVmd����p��4���ŏ(���e�S"V$����@z�P�4��s9��^�3�k�э��p�pRщ5�s����?����ğ�8�ݨ��nԝp�V�F�| ����22�M��1�ߜv�_�X����!�����H�uPNh��ď'���N��9����6i'���R��=-�>�C���V��7$΄8!����ސzԘ�[�g$ö����$0U�,M-r�<<{8 ��[�?>+}Z�lY��ϗ�4�}7������ta0�Q���Q��C����,��S;�B�'}`Q���	�^Z��D�AY�P��{�����5>N&(�	�$��,�g_��;Z,@\1��!2k�G����:nZ�p�x���D��&��"�ES'H���k�{����zy�Ѭ]�v�ֆ��d.�D���l0���ߨ��
�
�	�;�x`@9 L�^k��`�+_
�s�@V�vX��\��!��Xpڑˇ&eXd8�/��0���Ȩ���5�b��bm�
fɲ�l�q�KY�����i2���J U�|o��� ��WP\��+�+}����K����ۂ���:��?����gn���m���d��ün���M"�pb{�w9����hXȎ0o��g׮�*�����O�d�-s�ƞ�#hG��)`��Wj&�KOX�HV>{�6��|i�3*�{�(�-�j�0�io0P$?�vmw�Z	�b����+�>R�F~������]���`8�+�<{ĥB�������\-�)b�D�d��'D,"��3�%*u��W���]:E�����L�	��4�C���`�y�9�wk{ʱL��Th(̩<���9�����<WUW��$Hd~BN��e���·����JP3�&�a��ʬ6dU�^R��8[���tB��0�h�Gk�!e}	��A�[ x~�}X��W�Y=L�8(�7pĬ��	EV�%J�g/�<�4=3 ��y��sU�h�R��A���b��i:�ɚe~�7�o�+����q�PE�B����Yf$
$�o��Ow�P��9!HV�(�=EM��"�Ci�~����ct�ʏ������(vJa���:�C��S;��x�*U}��F� (�?��q
��Q|���X5�Ϟ(���roT(Cm~*� ��Y	� 4�`c5n��ܙR��gR��O��bP�.I�	l|�HFi5�p��0Hժ��Z��痬�X(�α<q�0*�(|H2�K4��J���4X}��?叔�'A��9�6�axn��u����qh��a�a��l�����$�Zh�*,pQ�W�}���zL)�&E����$L����È2��x���2' ����ցe�VG�nL1�{j����|��eA}61�B�~����Xi�Հ�k����$>��1����,#1�/;�1�^����<`t�l|m1����,N�LD�-c'*��M���b'�;��'�B�;,&��6��$IZ��ț%� �ǎ��S}���e��_�}�D�{�[c��]��~�U	Si�d�C��0���:�wȻ^���H�'�9n�Z��W���7�$��gW&gK�P��/
���,b�Z��[����4� �bb̛����^!8���7$�.�q�񹓣5Թ��<	�\M/�-]������PF�7()3Ac4�w�L�hj��@�~ sy^���ب�p��(N�j��+��E�dI�˼�b,���$��{�    �NsK�,�`^X����x�טChtWg�2�>�]^���uq�a��4K;��~�Tl1���|F<��"�������R|@FN1jh�2/ڐ��Lm���c~�\���-&�)'�)	{_E*Y��P��Z}��y�L�sNe�=�o�4�!S8�C}CyC �~�X6�fj�Y�`g���@�W�~���\Ǚ�x �0�A���f<(����Sy�񍋲IϏo+R:�f_ت��Ŀ�Z�<\�N�C�ނ[��ޫ����w"=:n��٦I�:<�
�;H��=���*4P����@�/���	���jxP���O;=wjɂ�8������7�`�jt������~�����G��IVL�y����#���ͅ�F�GMQ���a�����B�߻E�U�|U.���	�������N�G����2�/>L��*�G?(M�;K
[�?�$��%���G(Ì5@�o@/P'��1��=Ib�i!1~��gzRH�0Mοza��q,C������X.�X*�[z�t�fL�p?2�w�H@Z���RIѯ�%tJJ�ϋc^��"q̍?a�&I����	ڱ���v��)��g��m'��o�/��LQr�[Ē�`��Vd�1�_i��n�hNʸف�K����˝�IH�X�2� (�s�_c8��%�5G���2�P�ėt 	jٰ�í�Q�x�/�,Y�<�������@B��=	u�S��k'^2�^W�fv��';$͜�@�ƾ���'�����0�_���*X�`�n�����oW
~@�v郖ИS��)"���P�q���	���RjC2{�X�TSR��0�������?.+�2���/�<�Ee���}P؄���@8��:�d���I�x�x����h��b��l�Eǜ��O�<5$��⋄����To
I��\_Q��o�9]{O��r�=G�d�ų���S��~r��	a*�@���(��%@��kxخ�]^�
�V��Z;7�T}�$����ԠEi�_$hUf̈́�%I������W�9?c���~�b�1�S�OH���Lu��:Ī�8�S��-�~*���Q5D0�`2�U�G:H/��5
)<&){?{�l^�Sg�����?�;\�&�º���������24wnG#&n�"��!FE�9��������3��r?{p�4&7��B�?�@7P
<Wr8�p����]u�z�b�譤��P�jq����k2IE���hB]|8!�fE�%��ȭ�4f��0>�_�lȅ$؝��VT�
�|0�SWM9ˀ=1����۹߲n��`Sg�v";U"SYf�z�Z��dav[����^����ߵ�~�,��G=V~[�N�*�;G��^cB��\UK�d����{��j
��Nw;0W���� uT�W��I�3|8%�[Ӈ�~�B	<�4ە�,���`�s�I'	���Of�����'=�,z���zG���m� E��y�:���^p`�L!J�?�c^c�6=[]�"XP�Nt�3PiTʲk�â�*�(��	ǧ��(�E�o�/{�zkW(Wyqb?����OBm�!K�\��Z�(��@p�9 Y��9ƞ8�c�����$n����:�������]1(6�W��?#�1ꁧ���	䑝�~1�RJ�Щ����u�U����)qKc1������� �pd���lݴ��ctnD9�M<y��$�v���aJ�08��
��w��_��e��� L�S%�Pq��)�BH��p8'���Wi
���6�g�)�Pl��8fy����Q��[�~�)2�aTz��V�彯ƈ�W����|+n#��w5��۫l[�<I��˅ 
3ag���7�pǺ�%H0NJd�Y�ˡS_�����ګlA�"l�		6�RR�/qC��t���*�	��bP��*O$e��*�N���7�9���E�Ӌ�_���g��&C�����
p���w�In��z���1�0q�3>e�D�l��I�>:�_��kv��Ϥg��f�C.�"�w�;�j)2�>~���{��P��`�IK�T+�p���+��N�.險L���� 6�����B��B�������1�|@���6�j? 2��-1G���U�PF��Pբ My�]#�Χ�jCk��/�&�u��+�<yse��
{s�4ט��g�e��k`'1�v� ,����{��z�056�'T�y���X������)�����"u��Bx�
�ȝ���Q���`�.ח,���#Ϯ��1ǲg�Fb�q���җ�&����S����	�O��>Y�4�*V�3�ǾU�������>�0�yC�KΔ�+7b��+@���A��R�\��!���^��/#�p�x"37��T�����]觾�/�K����N��)=&Q�;S:`����J�y��#�v%���ꄑ���j�(R46���,2r��
�����}K���mF�2�A��>��Ǵq���"�.�Q��؍g�
��T�L��,H�� ��A7E~�e$|�v�
Zb=��u��
^�<�*�;u^��T\�,��.�B"�J�&!Q������lO��`�Y�0���BWus�;1��|t���8��޽5�LO1
ĜE(��� n�Zw�]:!k<8� ���v�-���~P���
�?�/�,���r�^Y���7;�,�~ӂYe A����蝖m�H7b8úc� obNR[|�]i-�d��	u^��PЏ�JZKV��F�(���V�(wa���U2�y{Tk�䰾4��=O\e8�8�a�nH��!����%��u�_��!M��:�o	�(^�0�"�(H6�4�i��l��R��(�
	E0 ������3@o�h]�P ͫh�+����������8���v�0�Q(I��� S^u�xV�<n��!�J1~�Y��8 -��L8KqV��_D�쫰��b
��iq��@<��{~��uMeZ��A�
o���~�Ox��4�h��=�n���4-�E�Eo2��a� �9G��@S�b�lZ%�9@�qr�%�_��`m#��H˼�����Â
\Ƿ\Q��0�-��G�6���!�\�Z:���ќ#��$l��HXB�W�t�FY�X(R�T6/�tB�rUҋ2�c������젾�t^Vא�J8�\�x�;��Y��cb�����.��7i�Nx��𥔀��袞ZV�>R��w ���l�XZ���mhŸ�s�j%\�:�t��� z0�*��"
`T�>*���썷�윮,@�	s�����R��+��"�:U��y�trг:�p�_U�A8�q.W:�g�X ��m����z(���n�a�J>^JȄ	�%�(���K���=�Y\�;lh�?��9�s�Fn�2� l00Xޱ(��q6Ew��S,.]��΋��ydaᄨ%I$�p�����%{5�Z�NdM'���Q(7�����,��y>�0
|)N�h�
A���x�7����7p��$('�(��s=��0IϽQ�pJ�`\�!u ;@
Jt��j���"?�q2{���T���IO�[&�,��͉����7���o`��~4��Q�/��q:�ZA�qX���#z1�H˫zi�Gz�/ej�C��K+o%� vb�ʟ�Qj0�u�FD`�[05�Yli/nc���^�~��U"L	��_���g޹@�a�%sN�G���`Ik�W��?0�i�`��B��><(B'0+���K^)� �Q[Am�i� RR�?,	�F݁C�vY���`5�2������9���)�ZUe&WKӮ������n��I�S��n5�B��������gAfo��qXt"�Eg(�`E�C-P�A��<��i:�&>B�&�NW��I5%�y&��8��W�=8R�7��.`]�^z������G�~�T��2��_�bj$�R��Hj�ݞj��D�z��K�ˉ�d��@�RPG9!�$~��(��:^�p�S8rm%:y��F��R��1K+Cz�{��f+��lf���`���υ��y�+7�t��bq��b�\騤i�Z��}�X    z#��x~��s{t�}v�~XX�A>�7���+TF2�#Uz���%��T�{���E�=5I[l��Z;��Ւ����T%iX�I��:_90i�eԒ<�W�=�`:3��h�9MCaR'ss�Z��'xe<J:2%���[�N�DF��]YI�:���&��-t�e����4�d%��3me,	Es�Tf	 ���Ҏ���ݡ��b�Y�.�92P|v���@6�B��	��QI4��$szx�=��V����k`�W�y�]�}�K/�T2/�7�}�:�܀�FV�E3�̢X��I<A���{U�<���b���jѱǃ�4�R�����d6J�	�+R�HO���d���|�<�N��gJ��!�q��i�e��=��X�î��F�;�鄜�������k����T~<�9,�\4������Ad�t���ru䬅��t>�k{qvH�<�h�%���6��$�����N������@3�LShZm����c�1%ЈP�.;�8<�k��X\����akD4�G�=��(��A6�'�^@\�>k�6�k&�9,��_�꯷���U�Or��'�`B'�a ��$��bOT�EWܑԳ�EH��6���*�*��C�[��T,e�!�*�#��%7@��C�����8r����>�\c7X�1
l A�2��S���Z�lY�T� sjd5�1(���5�s��,�D�(I1�2��2QuiK�Ͱ�?;%�t���ĔN�ޗbN;B���w�⮯��l0�NbV$'/�>�]j�U?��6[�i̲�p0Fgp��~����}��,�{�W����?�j;�����[�7p89K�|���Zh������l���QǠ���`6T�N��x.�*Df�t�x-�*� QG��_�?��^�bT�I()�G�B;�er�L�mx����H�,�H�Zd�$����f�۠�V{I���2s�%n`�Dٛ�8(q6�~v�\�0�w ���'���;��}��Y��?�c��W���#�L��"��Z��謁T� �;����bS�X\o����7Q�s��*�{A�q�g:îw��G}E.�����o0����J��A`���7xY/B������;d���[�ש�AY�߰�ʠ����:�׿��sSD�n��BM�������������I5��#���޺Q�qq���X��midS@�
�,*�j ���䆾^8!�E,��i4{��������MN�/�>��׃΄XQ�B�mu}S%�u���	�����>/�tJ-�f�/�n,���j{�U*P���J햣�ӯ���\���5tZdY����ܭ�S���TA��Ä?޴ʂoVd7���ğr��(t_��^� �7��NT�ח������|Ҝk;�R
�)�vs��/���%�a�C7��,[0w�y(�u)#Kk���9aeωMK5 �'@��Y>@`�#�t��y6�f7ݦ���2��~�C+�?{�� P�����=w���K�i���TC/��_��*t��[��p5��)�+�r!� $4EN(��Fߜk�{Q���_����f�������uԤRMV$��OS�2R�(�qヘ��&:��i�,Fr�+�i��f��|�qCX�GVjކ>�{@ ���do�s�Ipa��Kd���d�� O9�iz����	���u@\�������Mݘ=�g���� �`�'ʴi|�x������"�S�bT��&�[���8���U�nzk����2��CΑ�לJA:s�:K��.>����ď"!&g��6�C�q���Z�1��
:�Iq1	� �'Ĥ�S>Ff d; �LZ`A�g	��vl�����Y�����g1�Q!.��������aMhu� ��(���g~��Ak� �B�S�$�)�n��ʾ\�0(\��Ed�)'#h	W��/u�/���;`��P�
/I��S���d@T�l����h��� 6�ޫ��z��"6~c'�5�B�J�x�RD|DH)1��u��;��˃G��k�"���7$�ے%319D�EW!v=<}�8�l)�Q4*�e|�Xm{P^�ґ����@{^Bd����ɋ,��	�]G��4���L�b����;��0�������<�X��x��y���g���gΪ^�Q�z/�,��Ù�&:��J?�x����@VaK������Z�G�	re���ʅ��4��9 ����XG�h�2<9���OF����	�%�|u�g��k'a$�W��Y�Q��|�Dڝ�r`����Z��\�C1{ŝ�@Aba2��c�� ��O�h��BT�V��d~Oq˯�Q��I&�wY������;E���k5�QÉ�[&z3��e��Nuo�>I!+n du���`	_�<�}�����
]st���T6�<>g�����͜&��N��{��R�h�ķ�ӿ����w����)=]���o�X4o�ʁ�5��t���ԟ`Q��� �12��l��?�1,eGMR6�eړ�M��z��m#�ߒ_���JYL��@�3��?ן ���Η?F�f/��W��t��!+�~�[�s��;�E�`��nȀ2-�Ƥ�-f���<�Y13�J@>�E'�_�0�,��cgt_,���>��LƗ=�J��g�n�Ê/':p��ߋ�}�[�ؽ����Z����z�ɢ	L=�)R��Σ�;�P �q>�2�5��E�� ;�L���ns]f�,o{rHw�Q�eF�!�4~
��o�Hዮ_��~���W�	��y\��1FH`�e;g
�gu4߃���>��=~L[8��U�T�o^~Q(��O�5�;#�4������p��,�N�[Y� %S��j��i�Y�Ív,X
�`|MXW�� �A!��<���7�d��8y��� ������/5��^�\��f��B	F���.��&�o|��������L�~<!�E�;a>c0�	�Su�P۰���ʸ���������4��C�h1��-�uI���xvbq,ɥe�w��V���� �Yg�7!��-ٝת��N�1������gz�����8"�+�$ﵨ�α_�ĢPw�=z	�_8S�;^܋3,ܫ���#_�?QɓoQ����V�x�/�T�0��C߶���!z�=t��%z5�Q9��'�1j�r�8Ը�\�I����A<!�A!`���#^�X�Je:�{�����0��L.\���o�,�B3!XE�1��f�p�ա@�ծ��FW?:��4�X��^�o�����`���6h&��	"^�Dx��@�����g^'R���[�Ci����Y�w���X��鞒��)��D���)%_ű�Fp�f�<w���䑕�+�5��E&����f�nLRN0I3?s�"��f}��oD��'0;$5�8�jd*F�*+I�F�)��"���K�Hh�Gv����PֹEBu�r3��$�C�w�W��5�/X��}�����Me�l̓TÔ���fױ�1i�a���ea0�;,�I1��yI]��[X��8�l�e$��F7�%#VY%1�D�t��c�0JD��(v�4�M�d���2?r��b����f�@'����Z6��A��,),�X�׿	+��L�!�?�����GU��3փ��1Ub-,�#�U�A=�F��p<��Z*zћ�1H��Lb���e��3Y�A�I�-4��F��(�DZ �&�p�����/���BE�1�P���ҩ	LgX�;��W����iY�I�B/��7p��$�0l�B��cڏf_p��E��PA��lYAJ"�P�(F�nI��ic߹��o���-�W���į��	�8��x�yF0�p-2����[�@e��G�o�KsGw$$���a�s�o�U��P=y�F�	��nAgcH��\^��AiB�u��bxτu��,2�^�kÉU��9Ձg�:_��Tz����,z[b-�
��1�tހ!aI�*�p���W�x?�����3"��ٰv`�QG�#����ad�}8b]�T�L;�9��~��+�����q�r?b�+�a��J�G�5K�ݼ�w��a���    ~nP1eѮB�@"I�$�'�0%��Og/t���1��>`��_��k9y}VX�χi�a,�6��l�.�Íl�e��&�?(Sk&Hg	,�%���J7�,Q�0��K�-�:[юCPn@��̪f�|w��i$��~>{�
'��h]�k[�zT(p|b���P^�)� ��"� �ON�5�����al)��q4�8Y�z�79J�<v��εu�Ր��<���'����ODY)�ه�^�;�$�V<'���M��JFc>2�\2��vU��xF4�e��`�?�*M��	w9K#�A0S�l��(q��+c�`�����y���
��W�t
�SM1��p��i��%��fb�&u(��l��;�.�+��m���D
K��@�US"����rA$x��(��b�,%�"�����ť8��RY���� ��3jyx��E��8�uԘ	����D*� >AHi"�Bg~B�w����zl���	��A�� �~N�X�6�s�it/��	L����T�M����sU�oz�`��/�ͺS�+iDAepZ��V��̮u&���7�07A<�%'�S��t���	qa�I�*���8�RnI���8��+��^�i���^/B_�O6{���
ýU��=��T�'�� �����v��� M\aT��r$e1��,�=�F�o�y���ؠ芠_?2�
*;�I��/4��l �(�� kƀ�;�����Q9
�vcx�U��Gױ��p�;#�=������]�/��qUX���F��ec��>#Ͼ�<̗U+D������S�+cbL�TW��	T��i5��q��_5VQQM��Q�n�A̜&�����(��t����d����T �V��+H.1�wL!����� ��7x����0I����_Q�)�f�l����� R0�X�~3�?l��<� k��<ҹW�~��Q��?� =)_��x"rG���:���?�xN]LR�z��� �a D5��c��iu~ϒ'ԳH%R��p.'`Gv��]�{?���E4Z�n��ͧF��m�_�/K�lL�9��S�PQ8�E�^&�0�E�p2#��3y��|BH�@���0��ۡ';.�8���x+��!���}���?��9��>�6Z.ar�,�|�(��0��.�}e=f�*{�n�mD�Pm�H���37z�l`�F���{`������4�lL'D5WS� �g��xj@�i��t
gN���d�nPO���{o���"�?���2��r����?�J��'�y��/�pf��p�`_%y0;y\��%R��L��P,��&-&���W�� �=�0�|	ډ!��y03W%�Q���Q䔋 ����$�Ƨ/�"��3� ��NYU�ꠈ����A_L�!j|G%��e��~70<s��?��:'���@���70�XH�����G0n �V�2��c+�"-��Ez�2ǡ���H�z)U ~hnu�Qa~�]��h�*����Pހ�Y�T�?!���k(���(f��[�d �"�#g�{'{P��c7�;l��˺~�B�U5�~��,}C��>30Az�5,�wkb������6���`��OU����]yu�b��d����t:�o ��1hVTk�q_��(��֭w#d+h=��@w
`PE��n8L#`���U��� E��D��3X@�c���*7q�ǜ��׵;9j*� 6[�vj�����^�F�;��ѱr_��Ғ�@��(c�jۖV��G�x'�E���o���"����B��D�w˺]p�::�x�t�V�@,������8^�Z%�����v���'�9���\mS'q�O�j���؟�-Be2k�����9�� `^�$�z�t�gu
1�	A��A^�8���ʌ쳢Ty7}r~f�PSӦS�-���W�&��Sp�!<�]�,�38�b_��7��� �x�� �[M�D�������\(D��퉏���~ S�F�y>tX��7�ߵ,������a?�E't ��Žt@p�w%V��]�X�9�/8�}�w:t p:��Xga�?Q*�8HdN��Wݒ!$ R�*�	c��۷8|$�ק���x�G��͈+K���k>V��xfT��<)�f��OA�b��ԛaq@��imeG�N|����	f�E�幤�8���B�,�q���?�X-qt�Ѥ�:#Wo� Nf/���dw�z`T��qx���P�A�B�u�}Ug^s�Z�Z��KO+�V��)�w�t�5�~�O]�ńmDQ$��\q�,Vx�%Ůn�]����u���Q�Ki����8��s�ʩ$PNZ��X��\��U����T��~?pJSb*�7���:����y���g�aeEbq�A�������)��B�Rb$.�R�+���Ti!�g��#�7�}�~�]g�^Sj����V�QҮ;r���oS�(-𨪄o�G�8W�d�vk]��K�����RN��D�AGu����8v��1y�ī�ae��1P�!�v"���$g�(qg���P���J���_����ݖ�6���k�E=���R�-[3���d[��A	V��vDs��ϵ����o
W@L�ۖe�ܕ���O�78Ђ�J9����_/�n��#	���I����G߈ؤR�v���m�7#��2�#]Qs���;����$m�Hé��?��I�����֥�X��&в�	Et@Ǐ+�`���ɺ\�:*���A?:����a:��i�K"&G��RŽ�1�"���6��+ E���g���6�J#��J����=ѥ�[�S�;���ڟ�Ͼ�h��@`�ܨ���=QV�oB��ğ��8Ȟ�+ Ju�2�p�0s���V�IB����(�#tAU������ͽ�P�/�@����X�Y�����f1*�s�y*֮�I�{{�"�Ѧ��~��	�֏�x2��34�~X'�J߹s����kF�wy;#p���v����^����UkR�G}����B�s��7�ت�Uܛ�����7o�b���_yF��@QsקR(�W�P��<�{{y���k/I�\T��=����<9hv?Tb@���.�X;��ET�G�w����D��p�8@~���[^��o��=Dd�#띱/��E��[�������+�Cף�\n>q�tA�X�W(䈫�1��
���0�ͤwT1đ��ɢ/L3tQ}�*�E	'b٧$|**�s��5�����Թy�㠣X��f�R[�͋%�2���	6�ԐK��Z�4�j�RXtw
��Q��v�d{a���$:��'`=�^ ���c���|�A-����OT?��zz�j�Q�x1R�5.���pH4+���:����*�S�L=�#r����%�\�A7���*)�0�O�L'lݗ��\)"͔ѿ-%�_�j&Xһ�/�Yh�u�(���L�lw��J����ȯ tM������@�<���B5�G�\�dk:�Ռ�B�b�����MD�'F��cU!]����V�b�L}��H�jS.3����`�/�a����/'7���@�V`�k۪��^�8w�	CV����*���U��g��.�G��18��O�Nt��(�����S��4�O040#ՓùoGhy@7~r���	������-e,��\�6���t�g��m3�O��XáXr_DaZ���}�UE��m{=�O�)M���ӱ}�u"�t%|?�����+񷃎�X�K��;W{#�m;�]��%p�;z���+�Wv�b�-(A��և1��uqqp?<�t�||��L״3�t�������D��L���_>�'�ZO4���w�
�X���YW͸��o��H�/~�r�'�h���-�<~��w�`�g�&�z�1f�����}�E��J?:�).St��O�FH3o-�+~����������3x=�nNBU9�
A���Ru��,��5(���.�e�߾[��X�ʷԣ`�0᳦�����#�7���m4y�+�\�N�cEê�X�r��mv��&I�Z�f�"�>з��bh�Q�S�:?�����m/��=N�
���O    �9!+2���6��ㅁ���{�6À�^p�_}�㻺��IPw��W�}����uv�%�!,LD���yv9"��8�ҧ�^~��N�����2�-����@�g?[=�'S1~���ϧ�=n��P��!��zC�V�֧u�͈�{*��K;9{	gLXr%���hm7��<��+{��;�-fD�6
0-*a�������'�̏��Ʌ���ԽxS�j'���Ir�v��o�̽��T?�WoS��|D��`>�VmxjU�������<�SF1T�|TA��L�I�;g�fFuj��c�Fs\Y�>��b���9H��m���k45�q�
1Id�pTge��X.e�?PJͥ�c/�J:(A�/8z˞�eE!{_A���:C'�Vcx-p��\�<��iĘ��#\G��LP	�W�ݹ��� �۽W�h5�T˧�&Kg�]�T*�����傍����P�l�]�mm��܁�(�x�{�h����9�Ūb,��(�A��ۼs]�� �@��FFhӶ�X���8eْ��4�}��w��w;��`���^����Mq��e-���i'�/8䨤_x'�'�&��'�Ɇ����4O�#�#�]�I��P9�� ~M�pP��B�El�̭�"�t�D��L�B��OD����e��;�����jU(���#�R�+�_��)W��)��_�D�/����i�~�Y� ���8�"�@�lAĔ�@���æM�x�g�ɻ^�xc�eS�3�Ne���2�~Յ�⵨���-Da�ھ��bF�Ԩ�R�G����c���s�����)"�-���X}��ɜ�x�e���W{���
F��N%��*kzA݃-/�
��P���#nL֨�H�P��YMXG��$e<)�v�ߎ_P����2����� /��Q�T%��$��t���VL#���fst.9He|��=R�b�����r�M��?�� ��u���✀Ed#�-n��xc<�Od���[+����8���g)}�Rǜ#Z�2(���OP 
,p�F�Vg?�|�F�,��S�Y�	�#�W�+@��Mj��]���[*��O�� [�X�Uoo���y�o� ���.?�&�������(�}>��//�m\�3g]ǚ~K�E}����A7S��� N����Q	aD�V���o��E�4��ZVE��c�?�>�>�̹Cw�������uS�^W�_',[ת<][Xs���A}����+�4�cU�(�H+���6�m��M�=Y�mcDO@��7/�)��EX�v��ڈ�{Va������K������ #���5ȧ�>�2lZ!K
��v��^N��s��
����+%Z���j���}�����&�N�(�$�z0B�O�.���$�A���R��G)$l��v^�@]�Ȅ8�r5�%�+����{Ί����_���� ��F���م{�+y�����:M`=����QY����E��Y׵$�*�2h�{ԚW����ޘx,��vWj(��I�L���z�^\�3��'���_���sFP���s�ݰh"~�6.�4�&U�����3�Ä��CN��7���Y^8��\y3Y�d���,�o�g�YRh�Xe��b\�ǡP�'L��6�6��۽��ǎ�'�Ϣ܆ȥk�\g����t�*�ˣ�fTV�p\��V��pE�Q-����I�׷W�i�fJ��(t�	���x����^�?Շ�a3K%�l�^:,�x� �w�v���J�W3�[��R�o�lI	��I��<�}s!.��:�8����Pj2��I\�� /�(�`xT��ӓ����r+@�T}�*VpG�4mf�!S���*�`�T�;0��L�� �q�8@ZA�Rʻ}��r���@�Ĉa��I��ao�������7]�A:#����uD��H���b*���V�^���g4�Em���㈠� �^6�dR�,CZ����e)R�R���cESι��I�زN"b��38�oFՠ	V���� ���?���5f�`(���挅d/~e�ܖ3�PU\&���R��R��L�⟆���~���wb�Z'+xϪ�v3�gU$��mu�o��:�!��btNp��Z�c��
�R�e7���Ȯ�ȏ��l]��1	�L$t�=���؀q��6k���KeQg+x�j������2V�Ym��eǉ���h_��l)+���D�mi�P狟�ڸ�����-�S��3_�6��� Dw�uz�z�����bmV�No3C�&��Z+Ӻ�~�� u#<D�I��'��m~�ԛ��R��2�p���	$��#����6n]ֻ�D̻͒M��0d��9�+w�R�~�)j@;�2(��x|$+h�:��ψU���u���!L	o���T6V���`O�t8��E�W-����k
	��4FQ���B8��XI�� {%E�}��"	l���%	A������3d�ŕPE�8�~E�ً��˰AY����S��8�  ������@'�=�{�2)�ܿ��O���YT�d(-�E�N��
b��,~�d���팗=7e�Kx��@��D#���"�2�}�<�qr_p�q���q�L�w-��o�Xa��磸��ך����*Ԑ��(����ꑶ�.�+�mY�W3�sS��97���Mڂh��F��&�Q�p��#�nS���;ɓ��}4�Y��s5�O���q�0 �(�!��"0f�z5.0��A�ˊ����.#������}{�����e6�# 6�bw�l휎���w���6���3)^�4��?x#@���:�t�\A\�������g�ĥ���4,�hN��� �P���a9����U�A�A]~����^^V�̒8�g�,-�C/?��9�E�m�5��Uy:֟ձ�r:I��a�7ڝ��β$y���C���b�~������i<C:+���$d�2p�EѨC��*yU���5Ш),�@�`���+�U���i��h�};��y��x��>�]/�g;���hN�����<�/J���S{a�)�T|9GYS0�	C������ ��45������a�D�
��㣟�	����(T����o�{J�w�^�i=�b�&<"�n�-���Q���S�k�d�C�w3�]y�ԹE�}C����B]@����!�I���"^�w�f�;���J$�3��Ə����@��a4�%�� 2�4�(�����|=q�9�� f�
Nڶ1Ɍ���e-13ѿX�:X����Z@��r��+����[�n�����b�a�%ð��2���d���-m�Έo�B�iRD����7��N�X�c��xA�ؾre�Aն����y5iF���:6�L1�������b��>B�<�F��^Ϯ�������rh�&���A*V��٬�A�K&U�	����..K ��m����L�����b��p-�,�&}R����3�g�:�J��J����!I��}������a���Q��x��ľog,�s�/r��S,8��{RY�N���xm���:b�.�Y�|�Mc��=�y��+M���wH�b\�s�8�Icl9�Z�S�������(y���Ӕ&�ri?7i��Y)��W�r�x�0"�Å
D���iZ7sN���B�i�F��U\ZP����zޟ����`�gE��B���� e�Mn�G�E��z�rX�5�]�jT��W��w0:��y���4/�x��*�Dij\����J�Hj��*��`��OI%�-V[�3x�t>��;1�Ԛΰ�B8WPħ&Of(4�Н�w��~}^huz�/���J���Yr�j*t~>�
�R)0�޴G{��"iV�"�����J�c$�,���Ǎ����0�&⛯��]� N's��5���Ѷ�
�e��sz���RM^{��}Xﻂ�U��=�>�s��(h8���rU���_�����/�����7��{z�ѐH�5�
�=�=��`먼�Ř��j�P��j�rN�jᩥY�c���A���� lFseHP��Z��m��s�k7\F
H��mF$W@Y��6Ooo��    *�D�:-��:A�؉��[]�x�o~n�4�g���3y�4���Ƞ0U,�MA(т&�W�|��R��k�����Ox���^&��
��yQ�x���c�pY���Kw߈�>��3g�����zw����y�+K��b�j���@�;죠|T;CYs��? Ʃ׽,��l��I >��(���VX�%�V���{�Y7�t�;LWbp���Bj:R���n�T%V� 7�?�����`vp�}&��ޮ��*���s3�,���%���\*N������7�A0^�	~;*���Ƥ�v�F�7�V�a����7���Y.���a%��{M�Q��f��������$In��� ��"��-��3��'6d��W�Zb�����j�þ|�G����+��~O�eAkٷO'�
cWjQ�ҬW̘� `!J�.����0�
��z'Z:�[@{�o�w�*��в1փJ=MQ`reτHh���&��~*&���p��/��p���5���qV�@j�;�n?�����A�{���y􏑋)`�N�2jHދ�8���A}�8��j� ;���}����C�O�T*�'��`�㾻3�>����Er�i��-�Nt���R&Y�l�]�WkG�fo~K)G=�8�+��"��a��R����	%0�0����#�ȳ"��i��!�c�8q:�����j�`z"T��	�;����Our�r��~_j������\3BFG\��=��v�z	Z�v|?�� �83�T� O����<Cm�.S\ٽd7 �/׃E���_�?�P�4��V\��G*���IM���t}V����?�.��Bf	�z	��Yr�J�dy��!-�?H
����8�t���x��8<�q����h͓.&�/r����o�q%�8e��Ig��M�>}����"ш� � c�V�����e��@x��j)� ��17��Y�s�U$
�ɪ�ZJ�����?G��(
��N�]!3��%�����R?�3X�P%�����U�>xu��X����"����ao&�~w��A��5M�=��ji�`V��eɶ�1�7��ET#���˓�}�l�:�K%�XChK�ڕ�!=C�y����Qr��팙�)��$Rs!iv���z�*ɟ
�;7���)�@a�I�>���n����	u�I"O���oR�v*���@"�e߳��gW�y޿ml`+P�1]s�� 쪏~�ߔE���<sU�Αo(ܮ��@�c05��6^[�%�,����L��3�YZ}�f$��EE�'+�@J�Oa}�������a���}p��[4�t��ΩԿ�b].~���vaj��\��n��-�����A������j6�#���}t��C1��2���a���h�H��'a{�
>�_�/���2-:�Q�Ҕ���L�؊�x�m>E�N��dm1Wq?os���Z���������N/��N7�V�H�2��wb��Нdn�%N:�*	&H#���N��������Y��q[�Ͻ�ܻ6C.��y�K�� ܮ}c�#��7阡y�aL�=f��+h��
PYe�"E��J�������D?�	��0�����l2$�~BxV�����t��u�ᩢ?�E���.����p�N���E"B���I3c���b���u�t�������و���2���D��u�ܼ!u��7���6�;#xU&R穉#�":ha�@Иwb��>O���\ �������:�^eF�-29wx&����}f+h-��.g\aW#�r2M�G�E[=��`�
h��K�Jw��`G5��*-6������=�;�&,��)�^�RT𬎕ɷe��,j(�pr�|�@�iY�.�;G�p9�. �h�	a�#�
�y���D�r�}0X���
fʝK�.z��t(���I���.���,�<�����'`Ů|���<�Y܍����E��Q��9�>�`�5��
j�����k�"��TP�&���7 >���L�: ��>�oOq	V�/;L`�
�0Y�-�5M�ҶL`����J�Ӏ��y/Jbϛv��d�
�?[�3��E��*�Ɂ{�K[D1v����g��QzL-`��۬۬/����n��&�"^7��K�9��R�v�4;O���{�G�$j�<.fU~&G��"�!�5��._x�,��ny�X<g��с!�4��_>�|xK��ٌv�0u�_�J��8&ª�d��$�I��l�R]2��_&��R}Ċhلb+6�b"e��=�	����
Q1S�ͼ)Wp���UBk�jjx�\��b�'�������"G*�
� g��g2.́�p;/w�fF2,�Qٱ;w/�G�W�C���M�ޱ�J�C?�wT���F�q,����6��|յ)�<�(��㩣����4Y�lG9jr�#�
�Oy���Ԝ2.�B�M�M%g��5�Z>��EDI�6w�/�܄]U�9���	O��b t��w4ym�[�2q���q�"zo铷y޽�9���ޠݿ	<�Ďv{��pb���`��7�t���UU�+�������6Upף�pщ.����n\��cp�D��s�YY�>�+��k3U���/GX|�3pC���6���,)��I;�D+���*�H)�4-{zn�o��n�p���0B���~< u0uP;�G�%!0�V�o0�.Ng�v�Y!�[iG�u��+w�`��t��  cT!r,�p�FP�͕ K��+L������X���e>���$�aY	�P�C�,��-u>9�;M�=2�y��8��YA�,��gD��j�e�sO�J���8�� �}Y�n�x �x���O]��p�o���
�4�k�%P��nT]�q#Oז�@���t�m���~�F�4u���2����A��SF�D�K�a{w�������$�3i�?Ys���>o��
"@��/]�������z�'�7.ͫשPYW���dNdr]���lm0QI o����@��#�Ѱr��q'�ܠ�ޏ����|��qT����%(:�0q���o���IqF�̗�K�-��z��>��3��g�e�r��=�A����y
NW�b�
�OLR����\��_e�/bsUV��C����i��F�_�(܊Sy&��C
�.a��ߣI�$�US/<7g{��A�K��
����:NTj�"seᇜ6A�Mx����wo����)�<��]�[ �Dy/?��fy���7"��_��Av�O|�w�CG�»�'�-\[��Ղ?��_ۆ�
�����b�;���P0�Rl ����M�o�L�23(�Hh���#;d� �������v���/���`e��>y����7/�D�+p�2��;f�+� �j�������@�Wp���S�(��ʕ+P�4y�̰e-�L��B`��u��/	G���s,(LC�YޘqB��R@���o��{���q��w/Ыmv:ӗt���+�����R�^?(��6�T����]��S󤽐����#���X���6|�q����Bf`=��:���g�"���<DߎȂ��_%���þ
yI���A�-'A^���ƣz�?/��W�"����N�8���q�ة؉���[fc�&�1K�ꬖ�VYG�t��;����d.$�<����@v���!�Y�U��nG��I+�S��$A*E�"�}F@�y�u �E�/a���+X\��H��W�yV�梂k0T���rǊ�������O��*����eds�m��~ĵ-�"�WB'�NP�Y)ɀ;�6�W�ʋ ���폑�La3��+I@d(���(E�S�$.<x����~�S}u9�_���6�h������p��6KX�o�������G��&Q>���=X������J�M�V�Ĥ����^��D�M� ~��-#EI�\\z��q���@{�ut��b�|E�
N�Z��T�-n/�$�k)s�T6&��	��I��@JOH���do!��@K��Y5C1�J�L�U�E�7`Vh���yQ�l��`G��wMN��G���:x�%���f�|����>S�3i�
�����A@1�5"�3�:�f�2I�hpu�    �׭=��
"����Ƃ^
eVPΝD[����-��Jea�K�7Y!�� ��RrAD9�m�)}OWx��9?����>BJ	�?�z�P�����*:e$?��Z��#T@���L R/�|�e�����2i���y�Q�t`�>!�Ϗ���� �g�y<�=�J�BÕ�Ć^�m�B����c��	ܱ
�OP�܇T�
�զ�B����Jk�%�0�}F�h��w��_��t��	vё�0��ήG�4�_�.n��c�Zq��
��K@����m�3u0�%����J�;4dGzaQ��p�豈z\hH)��@R�(^��p,��*�b��ڮ���m~��E�7�ԠG��~;ʤܞ����P�͐���\��[PU��yS�Q�b��{O$�b���Pu�[�N�S�}�t"��'-��b	��8��|��j)���<綠Ú���>q.W`^nl�ΘnWy+I���{
ԌI�e7�(t.���v�$�/�-*:\��"S�{��Cc�|@��}߾ުLV钠��+�[6�j�P4���$gj�Tk�4�6Nf�E\+,���w�T")��ҝ�DBQEȑ��F/}�>���3�DS��}>�=e��H0��A�ޤ����(ð���UR����H�E��4g��z����.^H�T1���͕�XԍStѠp/��F��H�,�rP�7A[@+FY)>��>�xx�ΰ�sW�h{�#��/�.�{�_��ۣ�����8-��\)v��G�ah�,x/�:����	Ǚ��_�IV���WE�$��������=��6J����~!Nڋ�����f��}&�>��Ca�-2������,V�H8i��3���$Z\�iD�K�V�O�,oRd������U\҄�Y$�����"ֳ�P���^x����N���ĭ��'�"���ѵUE��>uGtW
>��%�\�ݮ=�^�+�eQ?�`�̹Y~y��j/&Iq�zv�E�mf�NU ��"�6��v�H
g�ۼۂ��<�;Z���9&8�2�0oS���2� ��s4_�ʸ0U=�t���8ї���EJ�Z�
!�O�m�`ܙ,|�o���|�:N��@�e��
P���aV��ύ�[-�����ʳ�n��� {,��ry�� \^��EWB׹V�U��W[�aB���u�gi���A4��W}���N&H�QDH	�Q�G�
pը���
f��3���$Ou�Q��y����B�{غ��/S�l�Q�#/�.�->_�����V�(u<��['u)�͙��t�$3D�)=�q�#(�����c�����P�&Ӫ,N"
��.�I��*�K�����u�,'<2S���� �a_Ak�4��~��E]H���NMϯg,�CG��d�!�ۈK�|�[���~�+�Y�G*�-4��x���30���P,)��g���囸u�&� �i9��ݯj�L����wk�L_4G7��$L�����ڜ��E��gU�P^������J�9��՗��胩L |
~{x�>m�e�F���K���`��)o *w
��-E�\4;�����Xފ��WN\���D�
Q1�'C�خ���p���j��|��,�_w�WpV[�43�*6!���<�Sq�����Q���:�yG.b[�tÈ��s��
P�E�Ō0/sJe��Դ�P`�´�x�ܒ;��nĉ#�y�h�d��#�F�xMe��#�+�	6��aS�T��.�Da +���'}�bGyKEB]�J/�X�� \X���9�MU�F�UF�|-,�H\�+�e|B���:"�D��ꆅ�.��Dn۵���̸��I��U�@�����8Z�Ꙡ��'��j�U`D}��[e�53�D�2Ѻ�����/&�dގ�Q�;%J�RW�@C�V�I+��5�3Uf"�%q�?��m/�y�8�������U+�f��z�ZeD����3=ëFMއ
��
�a�7�7�2���&у0:8A/`g7��B��e*��se�NpR�� F�w���?=)�����k�Cϒ�k���?X�3�����M/�B��q8���&^1[5�4�mo��Sn2O���%Y�.R{ٝp����

"�=����[ѵ�Hb�D��$���O4N!���	@�ӓ�Qa|G�M�
�6���kֲη�2Y'WK����"��+�p~����	���O��>"b���[e�6�=bYY���ї�"���:Cs$}��g�V-��D���Ai/Dl�ǲM�n��3�X=v"2W9��6�՝F�A�����A�eǎH+�Tg�}s{�L���B&U�@�?0]�k�7G?�Z�;�]B`���6��	"(ERjn���F�
ٛ��5�A�Wh"���`5R�}cgܭ2.*91iQ��������z~��ի��E�$��ouYeZM�ID��F�`/
��^�e"F���(�+�M����V�@���Y�m0��Ƌ���/����,���ѭ#D�2�I$�i���W�<��A�O��G37�r���+�*�M;��չ|Q�B��d�N�Z���د
��as�6<g�d�|��9�i����������O��?�i�G&T����Pt;A�L=<��p9��@~�
Q������fЛ�+�g����V����'�$�}����pI�=�Ě_�l2��v��s�#��0�����- i�����>UC9|�˟�Ue�ܪd����vZD��t�cF�a���������ڔ'�������z0����Iᗮ`GP�8V3����E�>K����9��N�M��Ii3�@�?S��~T���!O�^�u�If���"�����U]W3J�$�L���'\v��9���]���d-�N��� V�$n��>#�3S�qs��{���<j�$v����+�_���+����AÔ{Cw��?�к��
���I��+�ĸbI����o�գ�:Sl�ξې�t�6J)���2����?�
���?��S��0FT��,�>���H׼*���ຸ	�P7,ǁ�d@F�Ȱ�GQL�i�����fIs��T��,K�{�
���>Z�*��u���"���7OC�-|��sxq��a8�=�,U'E�>�J*�j�e�����,�B"j�j�-�Yeq@�˙����B ���Ԛj�I����1�>�~���mk/d�Q��Rf�g�?�^$���{R��l�5_��Yu�<+�M��73є3N�ߨ�Et��6�_�=�4������"�ڬ ��/�j�6��e]�d�b��/?��|)w��u@l�5n
��{����ᭂ>��3��2�����tz����WA�\��z�
�7�"d��:ϕ�/��n��ym(���ºrU��}-Dy}Ū��:���f3N�]��J�n�N5��u�ڊ��q&�u���@�i�heRG��Z@!�b��z�.������S��^�V&�Ke�
��me�1��"#��q�!�ܽ���	�u�Ky	��
L8�M��2#�\����QU�DD�^A��[s{��I�kT���c���g�w������D ��V%����������ʘ�ߴL����4�B������t/�d�r	��	^��?^�:VW��ع�/�?��q��H�U\�������/v�Yʰg/��g�	�Y��hk��'h�9��ڙ���w����Z����q9�8�e���=�H;<{���7"�]F�:ʫu��t���&T���ڤ}>������M�P��}[�@eg���3U���*���W�Sj�¦���,q�Y��":�3i2#^�����:/��a�TGDk����Mz{���q\�%,��ë���i�fYyl���N��@]�oϞY�-��e@�V`�ڔUU޾�ɲ8y��4��Ѩv�m�Xw�H����u?R%[��s1��J��)�T~f�HS�	�?��������Ga/�N>5r�Ei,&-G�G� 1 '�D���E9��%��m�Y�P��*���K��.���=�H[<_��vE�|0,��|���Y-~��*�T��e<����80������wX4x�+�5�g���0�@�����v�a�    _����ͨڤ�ʈx�1��ྈl���P�����Y����Z�P}�\�&��b^�b��8���N�j�O���g��q����@�u�]sꀈ�d���DG���ڸ^AV�V.��DShR1	���}�b"��LA���x�À�����5]ZωKQ&�&��
�k.cԛ����=����$ˇ�4v��@�geiD�53YD9z�j�����9�^�m�(��*4p���M��i�|U��lM�s�jH��z��4 w��YAg/�����he�x/�TmS����1�8��1���ހp[�����>��?��k�P7g���x\m��ȓT5��k����wLyr��,_k��HIu�"^����'�o�����	�͘寠�fk����<uM���H�@�����^&����1*&{9<}����'VL:�ڋ R�h:m�OV�j71��8�R�C���@��
D�j;���y�z׺��V�!:�����h��[���7�8�?x�P~~���J;�K�K�.��"<�.�pP����$h@o��H�i���bf�(��	F�������>�_�NL���I@M斛Obs��� h
L��(���l[���fr߀_כ*��#�>>ePl��²�n�o+.7�CU�9����Y�X�+t���C�<ϋLۅ:���qj����d5'�ug+�;��YV`t�q��������y+�&��ض��d�Cjr����WUaQ�My�H%�s)ML�b�\S5|D�^�b�&�&�ׅe\�DfV�B�c���<����Tt�?���=�p�|Jq_1[���i�����2)2�j�j�� ��BJ�{��*[�6bd�#4k(�$If�΅�?�%�b7���.\E5�s��O���l����a����3F�~�}��Z���DO#(���]d�\7����m��C�Ms���y�C����F�jd���=�h�ouܭ�g�6��- 0B��r|\�W��I]���~�}�
�mN�� ㇣� ~Q�=�W�s'rP)�3fwk'x|S��@�͸��.6��BJ�[4��?y�[wxq���v�f�p�23��4����	�6�;c���T�,.yl�|V�,E��)�v�'�������
~[�m�-c��*�Xd�8;���U���-����N�>��Q<(��C8�$.��W�m\T3�fy�':
- ���uో���r'U"��{�����cb����\ϵҋ��{7O�`�P�������r�H!P���~m�7]>#Pu��}+��T�o9�SZ��I{���W�Bd���j������4ʕ+���h$�B���C��"8dG/�O�%��<P+�?m��3�oLj�R�UE=�<���P�]1��ᶫN���6������_v����q+��j�EUǷ�Z&��XZ�;-�S��6ʷ9��)�%�dQ�<���WlTD�2\[n�b�mt�#��{(�؜��?��7q�������y�Ԝ��6�çcw=�!e3&�( �n�ym�u:#tu��%D��]��~O�c�_1��Z]�O���dV�������������4�͕���}���R�:Jw����
�Q:�@&��D���ǻ+��#a���d�V�Z4����f�:��Q��yy�<��b0����Zp>����2�o�:&|�{�_&	:�y�ђ��;6�Q${7��x���uխ���L��l�1]����a-۠������,�z��Fع{q ]�w�k���^���������^JO���渖��]���mvX_�۝Z��Z���y�g��a{A�c� �xUM�j�?/V�`�~�v{;�Ӕ&Q�~	�s�e(g$��Ԗ�j�X�XI����-��s�K/�	$�t�@ ��Y~���T&U���D���&)�^� �_-�
�N8)ƌ��Qo����.v�cFV�M�J�e=`�.���Q]P���c�w`�%�Q����O�D�V��:�A�.bc|�J�����w�szNY��e��wa���T�\~��@1�=X�)tRV�WPT%��m�(k+���Y�+�á�^~���U���O@�I��%������.�Su?��I<
�=�yD6;�ierB�=0�P*�u��|�4�Cl�\W��g�]uXh�Vő���P`�`�}}㺎g �Lo��i|���z7�ؚ<�����J�T�z�w�@"�6�b��AP������າ�fp��<O��Z��J���W��Ij�}.+O�G+d��(j���2�nƕ�k��Y�E0�KDH�������&�+�!|�T��)eWgɌ�I�q�t�U���$��z��d3^��߁�E�=8Hm���"%6���}�����\��Q��ur���peY��Ӏ�t=Y��F�.'����5�dߌ}s8o:&��QQD6T;$��I]�'0(R��Dα\Mx"j1��_���TI'�?^�A&Ҵ�꯬����^�ys l��7�'r!?��6�,��n����y�WZ�ܟ�x�qޞ��Z�y�z>8
Z D�3�TK�vt��DEmɯ��ȨmaK���gu]��\�R�2�ׂ��gi:����!e�s��{�_���U�\eUf��y�m��BQ&����2z��.$yo0���ش~K�����FԊm9��*C[E���r����:Z������d/4�{��G��`���j�����vF�^%U����,Ah"tm�xñ�85��<[6��9q)Se��q���~�	J)�)(z�9��P(.�, �Lvw�����x�25lv�_--�E$#s�@u������w�A�F=��_#����OS��i�� M�z��+�~����v���e�R��,�9�Mԧ@�|��D	<�SV3�=P��[>�+u!�ש�a�w�4��~&B|ߺr��4�lg"����B���`�~�<�NՅ��h�t�$���=����~�m��3�Qű�#DDx>G�6�'��m\٥J<�*Y>���UW�3����30Ϝ�5�N`�*�ʑ?����L�Dyp�oA�A���)�Y�����25����*,�Ƒwx��ѸS:`�4��)�8��#�1��A6�\�%0ں�>H#N(�T^E۞/4/�p�3�]�>��`��@p�y�S�0��ce���g���JN���W$��0]�;Q׋�HyY8{1��'I���
tmU&3���1FYUu���P �'82��s%0 ��x�<t���Vp9��ΈXa�����좇��:Kp�.���F}�0y=����^�V`������i��;�B e�I?�ۼ�dHƹ��[y��w��E��e@蕉@��� DO�~��i��n����2*s���/T�ưH������@X���t�����ߎ�Ysj���N��@��7��^E��5�~>k��p�:#��U:)�%�v�>�� �j]∮���nˢ�A�r�:.�&�G8�����U*4�5�K�钪+M����S��	A}��E�soix�	4��W�܏���%���nYi�K(a?ՊP4�DB���A/��!�z�6b���i�hq{l���MF	�W%�Ᵽ5
	~xB��^�v�o���0�W�W��AWs`U\'2v��cG��w��w3�D2��#:��rC��a{=�1L�Q��'�����X0K����קI�ߞ����r=}&��i��A���U-O,�˃�/k�g�v{{7Z�U�+�[EmzsSkAu�]ʽ���)�� l���1[�2cob;Cæʪ�,%fe��wY�O�-=%6̶'��qGE��b�Ws�k�j�tP���Uf^qF��"�����VŌ����K%�X@v�W*:J"Nm�$�2�0�*z����*�EY��~F��]hrNU��}[+H"U���'T���a�Y-�@��a���+�坫���I("R-�D�k����UE��}���`�����b�	��+%�Шu ��(� 4u��^�Ve�r��$��F�M��h�6\C�7n#���ۮ�Ag��4    ;�<I�/(K��$�v@�����H�9�D_��@���+ XQ�J��=����Ҵ��A(�j�W��j}�®B���sP��*��L�G (:���6T ���w������`�� B=$�+����ܘx>~;�r=R�-�^K!Jr��=����a���W�g�D�y
�Hj]$e��|UGnD�����U'���I��!�Ԍi�S#�߃�����#�I�?��m��s�S��K����3@��?�9���c��Q�ui�	�?��|Qn��?ɖ{��2��:6�x�牉~��Z\�1����E����w���n���I�ǚ���aD��8�$�Zm�	sa�GG�Q���c��^�d�{���mZU%Dx��A���ۇ?u�XcI|��xxD7����6�1>��?�}�����:-������>Ob'�_�;{i�|ۗ���mflM�,O+-����?�2���\A�B���
یX*�#P�
NM�m���exq���8zo_y����+5%D$��c��d�띗��%�4����ɺ�%)�s���w(}��!0y)j�y
�(�
�8��
4I��WBD���}\���V]��>"i�%tl�Dګ��T9u���OWҠO��X�5x04	h+�����������!�v�ݣ%�� �F0��=���4Ǆ+��ٞ�*�V��l��@��y���	V�td���L��G��Qpo�B��L�K����Dy�u�����y�Mw�>�^�u�%Y}����?��4x�ms���s�T�^|��tީ���U%\o
z����6}\gu=�y/�B���4�NBjn0�1�`�ņ�����yր�=����|�<��t�ܼ�lU��k#\�ŏD����P⺬�XS��Q�(T{�A|�-���y��ˏ�r�F�BZM��m�d���LZ	�k��A���4oOP�8���	���kՑW�����ɣo<�H�� xf5l[�3���y�w��ީp�85��D4��B������<?Ӏ<�g���%z��ų�%==B[,~p��]3�Ʀ�]n��XZ�g� SD�EXO�������/�˝��ߋe7&i>�BKP�W��	��%��/r�ζ4"���#)�+ �1ъ�׃�GE?�[q���9"0�+�C_��D��Sx@+!��v���/t-����^��G�JP� A@_<�g�~��#B:� �<��ï����"� ���5��RTL��?�A ��\���()���P#���u)���.�������
N��[{k�G^�bB����W�
U��w���iH}Vә�����fw�����2/��4\᷻2 �rZ-�ENb���,+Beq���{��/V��pN�̓�޹8z�橓�3a�QǇ���)Is�	��`ja��Y=�{Ji.o�K��/A�ý�S��Q
���.�;�x��ʾ�;|<˿�I����<s]��Y�;2ɫ����o�\A������S�!�sꭻ������I�H�f��,%�'Ykof�"�u���,��#[�R�y`�*��4�''�t/޼nH�Ϳ";���+Zn�|ƱˋL�K�G���2�1i�� 
{���H�����q?ɨ�4��y���Շ��!�˗o���zƙ4Y�F�$�y��Q��]�)��]�}?A]f�W�2m�32n��%�"��Gn�ؔ���"�2DT�j��V-�G��T�8���`ԩ�I��7"o`�	�xh�?i��o�F���.����^*d/i�:{nO���չ�Q hx��i{�j�g�+�]�0�s�3�/Q��YH�(��C?en�|�P���;hp'ۣ�w��_�O�����	9�b������J y���~��@��Ӭ�Q��no?�e\k=XF�@����,�kj��C/�Z7��b���)�&�����M*3���~�Fr������[Lx=8�ўd,�.�/��^��#��H�&BY.��l˦��4����u�](��Vd�4:g��Ѧ�o�j��B�>�s|�t�O)���H�AV� 	�����x�u�+�<�>`4�w* ��m���9 05'�w p!���T�p�a�Wp�mQ�l���%�;�$��m@��եi\���z]]2����;�6n���y�| K�۸�=U$��U u��f�jy��UU��-����DĂ/�ï*Ӥug߁!KoR�y��gӤ0���a�Vڑ�Y�/�'2u��{�F�'�TjF�xYd��t��^��UO?Y��FDOj�2
^�O����m�g�$Q1�! �L���J���ND��W�z獺F�����룎�������v��٣k�2�*�WP ����O]��jeX+�1!��>Z�Չ�Gy���Z�
��|y=ةC��èeB�d'0J!r�}��N������t�k�U�e������A
��c&
A��v����x��z�Ȍ��WӉ���񢞹�E`W�"��I�۳s�W���幉@�H[�݅���Q�:Bpssݚ:���$r��Bx�����W��SST��S���F^y��|+�K|��;*�w��(�]��'�������é�W�2'7��R�E�f��Q,bOo�]�'ܼA���M�t���M	���$������bW�L�2��B��J�cav��p'yG��-��~|�-�`�ðv�!)�<�a^G_��!󀹢��XPoi�zo5=���\��U�ʖsޱ�̕�n��4k�3�5�pq�&/:��n� %^?A(/���g��7�P�j�z9¦JZ�.V��y��4Q�Y=�V�B�M2�����A�xʓ�*�]����}��~�4B3>|R+h@�&Nf4 ��3ҁ�4z��(s�QO��k�( X8o���Z�Km�d�+�t�~��]��Lylj�F����b+�D����Z�N�K�u�4 )�H�UI�}*˟'�m���2��Tg�Ƶ/�Xb5�P?a@�B���<��@��JcU"ۈ����R�+�AV��g��&[����fF���E�h`M�@[�L�u�w����f=��,gZ
��>��o?R�f��J\�"��)"��{)�O��G�tJ��<�ܝXE"ciB\�Ǉ��گ����`��;\F��Z�\��*xX�	�M��A��L�1@h���v�������Ü����u9�H@W�[���޾ISS*	�T�a:>Қ�L�F��o,��M�E�Q�
��
p�YR�u_�e�j3u�	��?�^NF�{`Q4��ߍ(^�<� �f��v����^�%�R{�{������W��o��i��G������tx
>#T��2�:�������_���)�)�R��N(e��8��e��f���A�` ����qz�B����=ж���
T�@��Be��z��� �a`�SX-���v�23ͳB)xE�i�p��ᗉ �V^G/���1�3p������=���h�o5�gy�f3jB����0�����41�r+����,�}\�YR���H�?Q��D�ː��T�n�vo/��10W�
^���f��)�2O�/>/2��<��BO����:���&���5�SO�����9d�˗�:��W���ً<"�L���Ct���W��'�AbȤ�+�{΍�������yt��|ny.��O��I����sya��Zu�40Q(�"��1��w�ψP����ټ��w�q��|�ޙ� {LH��n�0Phu(E1������by�'��&,�d�4K��`FQ�yB��@�ګRaa��i�s�EQ沪0n!r|��+b��`���ٵ��1��HZR��%P�Ƿk+� �Y�8����#�[�o'��%G���yDhV ��c����,K�2 /��'�z
�O�E������~����3 $�Z� g"�)�
��U{{��\�P1�2�>�MA)��'���w^U��F/j�z-�^��/�isw�$�7��Ij���I�A�m���h�_�H%yN�,�<�7K	���g;}��/��s�f\��=W2)������`hΙ�G)�tm�ۻ�!&.�#P ��ջ�5�Y�xu4����    Jrq�"B|W�x�������8Sո������ ?�	�f������4\��<9ي�z�|��n��>�/£��� y�M�9���B2m������deGx��i�G9@���bU�d(��ƯxP�����f��S��ۺ=�U��g�D!��ݏ�;��ݠ0
�/��˛��g�޺Nc=dEt怒]E�?�f�p����І։_&���I�/^>w4�v�T����~ �V�1�
`fy�f���Ε��n��2�%[6�o\���_�:��;_�!��>��=��N�x��a�|��>�ꦟ��2��}�*�ױ�')uH���z7W &���Hn���i�*г���wE���U�EFao��Y�C��h�&����<�b�l��0T"������XM�'pE��2x:��B�җ'���i�X�����,
��>���6äI>C�!w'G�u�
���4r/�n�1	��0��ă�����P��"���Ç����d�v{��$7e��*uy���ܭ˜�"�{���( ��$���4����<�#j+h&���x��(�H���:�׋ ! �$g�]���)�|;�>V�IU�	���c����:��MO��Cp�Cd���L�63����D���:�$<0�dx��B�Ԗ��$�Q#�U�6j\q���>������6��>��|�=�Zӣ��P���Y��F�ߩ"h�ɀYW�Pd�ӓl䏗���g�1���Mу�7���<P-i)���q�L̼Ȯ��=?���v=�㲐P���R���f`���B�1n;GPu��V�2�۔� 3���^QI��i�uy�U�3^���=���K(Ĥ�a�l�D��w�f�w��o���\�U�.� a���fk��u���@g����Q�H�/��
Rg�:��'X�3>�OJux=X��GME8)��e��ɓAd�q�G4�犻/��G �¼�/�џdu��"���=�/��_a��C0���&ҡ,�FG�4(�e�&T��^(?FǊoG�EQu=���-@��b����!�E�4��yp�do9^'BX����+8�m��ۇk&�r#{骊ޝ.oܱ��S�èM���?��p�@�-�����*|k���Q�#:��O����T��I�OMD����Ai�`i�N)�j������JfU�0�:���z)�T��� �D͟2���
����t�����U��N"��Q ��f�\U��P"�󫼥4���\� /�Y/���(���*�ǈm�e7t����ۻ���U;8�jy���{,�uz�����1�-�Y �u����7ew�4�uje%Y��"z�P_�kY�r�cW����vf�Y��)<YE"�Y~�ZE��xƪ�V?�:��6'E��>ދba�8d��e�����,��[�#����������^�VAY�PAQm�r�ᨋ:֗��~�ѫRI� R'�v@)L�T��+}%AVVvQ�<����g�_mu�$�O9�8�՚�.#����~v =&ug�	�kg���m�7'H�3�D�d�x��E<#nu���5��.�#����C����s!���@Al�Zv�
6N��V�v�d�������~�^�脖��H`c�V��ۚ��DT$������Ѭ� �v�H�D�h���\)���I�EkD$��X*�6��t�^)�Ź��}�ψW]�����'8��:<f���tĭyV4��=�0���Ɓ=�����A��v�.UzU*1K�?����+��ڿm{e�C������S��2�^��X����{S�+�k�Y�?"�A&��K�?=pj��Q����3��EX�oFj������������Kq�K^����7�!1�!����7�e@���t	R��0�ӵ��D��$S�?$垠��oޙ��7��Ӂ�D�ID�w0�,�i���Oڊ��g��<�M)'5��@vNG@���W{�G�ђ>�Yke����Uo�#v��W�����������y�����i��rn�;�x��E؁\���L��xڍ�^(G��pPF��l��_ʤ�3�"�)�J�J}Dz��\E��x�����9���ڶ��<��s���n�����L�v�BS�2�p�L\D��`MI�"��5�R�钤2|��W��oPD�[A�Vf}[���Mn$pe��8K0w���Y��݁�b-�h�V�m��A�4�Lz�Vж��-�n�e����U9WA��+���h �����az�X� ��'���SY��ٹ�ro�V�u�;D��H!�E��솗c��pnNs����)lE�[.j�S��]r:_��jw���6RQ��+�J��^|�Łc��*��\/����/�d��W��v�
�m]'��#�2.�$�p%ѯ�H�؃ž\_�uS9�Q�,�T`��E��+(C�i5�)S��f�4���+H y�׭xxP��輋��G�e�53��˴�3�$Y���o�O ҏ�V6DZ�C��dG�&^6�up0<>0#H_�PoK���3�e����m�<��mi��V�yx�A��i�E7����w�B�9����I�2�t�W����m�0=|�x�����ĩ���=@l�^� $*�!��ψ0����S�4��r�`�Ed�B�ȍ��s�?�;U]T�ET�F��� �iB��F��?D�,�Z��j��+-]S��URF?y;�O*U�]
D0��Q���F9ܣζ�b���rem?��(��Ч�����z'�#7��<c"��A�������+�!J+�eUE���e��%J�*sh�y�6�R�(A��`$��5�^~�T�e9�A�ˬ�-����{����m�Sή��t�W��H�)y��zǪ�m~��⼎5LI�E���3.&^/�* /��0��^����;�{��}Uw=ZI��2�H��#�>\嵻f�*с�U�vU�I�BN{{�v0���OB��u�� ◬ ~ۼ�oχU�֩��4�>��KC��`���ۼةd�o�ĝg�Aq��n�.�aL��¯ڮ�!�Te��К�5ގ�w�?~��F��E;�T������'�sD�`�5���ˋ�iT�)q���o�Xun�^w��LC'<���V@4����1��LZ�1�"�U�VQB���9]�%�u�H;SnH�ATV@v����ͮ���Q)�Ϫs!�C�ϗSs�����{��
O6f7�6����^�1�y��-���'��Nֺ~H.C����';��{~�PL�:�L5rօ(}�?�=v��"Bq�2����H�'uJ]�!�˙1Ӆ��g�d;�6��@
�8�E�m:=M`��k��#��@��t=�~L
��4��&�~P���@w��$p�Ƒl�Z�� ���ei�Z����o�zNs��ǳN�kJo?�e��m�Uq��b�={�E2�z�_��{�ގ�F#8��~�D���w�%��3�W'�l��:��� ���?�\�n\>���C$�ya��)o_��U+Y޶͌�����%s�EY�Q��mV(�E)�D�1Z� Cm���}!Uձ:�,��	%H��c�IJ��E�H\v�J��_G
�bO|�ܳv~�Nf��Hu���๣��K��d�z����:��TH{���c�(��EF��~�lO��z#b�9��#¹�=M]橽=��(�tY6�EiiCdf׀_���3��@ A��zΩ2�Y����>������.ZWI>#��q'RAfy����o����\��?q�+[ΰA��$���5�u��Q�<`@GmA�N��IK�^��H)��u��'.5l�,�r�T0d���j�Cx���&�J���_�WLg�?p2���ǀ1{���R������@S��Zp�����#�L��Fe�}�����A���̿����"�X��^i��N��-|��`$�ʝ�������8�xt.�|�#��ng������[�S��O���A�����'��r���Y��8�˟	ԍ+�g-Mc�5Y=��u��4���'�&= ><��Kߡ���4�t�
f[cfH.�i�����*Y���W����٥�g���kz���<�rNS���+(��4�!�Yg�I55�ѽ    ˓��Aq������C�}�Hj+����2�s���o��|�n�c�]��RY`D�ZA]��EψnY�l����'+�ڞ�;�W���hbɞ���hs��T��!^k�ɺv�lj����4y��}c��� >d�*a��:���2-����j[���W.�I�R�X��]�t@j��#y�%�����/��h�nE,��<��fF�pi�V�]L~�]���/^����b)�~>��B��,��k����'��i�W3B�� !ͣ���w�j���]�2����(���i|�8G��,��]�p��
�pM��34�H3����7%v�����۱��hɢ�|�`��� 8���G�MZ�Ռ�X�.�A^D���.o*j1>i�kQ���@{�!�#=�~�
�a���9I�Jr�!��8� Zmq��'�Q� �[����W�~rQG��yb�&�b�S����<o]'y�9��>������G�fw0��6�α/0({�HS�^V�xq�7R��d���n�$ �%i�״v]ի�$���qD����ex�fﲹ��.���Pt������
"U����%���M}�P�m���h���S�kƽ��|l\��:�T�A��S�Vw�w.��kIRu�Db-O�}>m�>���>�HX6i�#�7�nO���F[���Sn�,�v��=�I�]���D�4�פ���]PS$S���V(�D�h7\�����;+��˫����J�Ύ�EP�ћ�#��nTe;�|d�(_G�^A.�K�̸�ilR=�I��we>*�x=���C~;������}��}�T@a*��>q�m@��7��d����m���,ֶ֠e�8�\����yj��a�^�ݮ�
P8E�� L4��� ���ǳ.:��;9ߎ��lL�����`�t��*􌂣4j	;:��R`�G�{DU�O�+�E���t�������G��&���?�&�>���+�!���h.�E讀!1�`��W���熑z� +
��K��!ava9�U���És����3`|���(���d��a���"-�vy�@B�������=Js�<a׽���5�'�4&]�s���f9CD�6�849�<��Im���7A�3���r�L��$VPr����g�"e�Tg�D�3�XL����uLC�dO{ne;�m��i|{P���m�)����7�ع7�Ң�}�C��~��ݡ��7Љ?UӘl�����uH!�+ mS��3�lYe��2z��9}���+#2�^���ⵁ�!R�
"�mm1���J�e��D�P��ש1.,~�H��|���7�<~-	�b��
 �[����bW���LSG�.�Rr�'�z��v,3y���۴��]�����ε^k|F�'�l����Vz���P�[EL#Q"R�N�wTG @�^��Cy�X0��aD��?�����,|X⪄q��J����.���{�%��l[�7ނOP�1��)ɒ�ۖ�c����1T�E�D����Z{g�q�%�|��8�JR�ff�i�IUF�$�D`�{FP��,nT�9�^$2���p5�o^�5�>��_ٮ+�'���$5V��&�B�W�Wj��I<�4{֝$Z	��\S��l���c=!����w�iv���`e&/��5����ީ7虮]����_���7����d2�|�[��DWg6��2�]�ry��*z/��[pu@B�q���@���Z��<�V��@�u[Ȭ}�N�	s��n�n괸?	'�q�O�^����/j��
\��pr��~V���K�<K'���'p��2�vH��ɵ)�@��`O��R1V�m�5l�QE���H��Kb�$�˗[���{C�U�����	�7��5��Sq�=tȽ�	���ھ�e����\y����*I�v�5�?�|ɵkȳ{y =����lϊrc[v|�n��բ��%�+]"޷j���<��]Z�3r���i�����Sڣ�QT�N�����⾪gL��!#h�⋘�u��~��71(ׄ[������r��s'�9xO!\��/��$�_�م�,Rͻe�s4�b����U䞄j!�E�4^q��.W���FZ��
5g�G:���g�nR;�BڼJd cl� ?�~��Ű/���L�������Q߫��L�d��KC�N�B}#Cx��1�縀Ú�7oF���T%yL�#su
�Wˢ��[�
A�U޸��V��
|���^F*l��J-]�~S���_=�V��HGo��%[J�mM��_o�P�N6�a2AF.g_� ���oB����h��<�S,�$�$;��'��N��m��y�Ɍ�$a��Cy��Wc����˜�i��FoGR��y& 1�2�ޮ(ײ�ט�@�6�M���Yi'RǔY�I��E.y��I����	�zg݌�X�	J.�{x9���z
297�^���bC�����\x�Z�;���� .���i����:Ns��P�,��>)M�"�ZX_���ɞ��À0�Oh�u��q���R�Zi�Ϯ���֞�q}A�κ��` ��N��|q����<A� 4m���1�LMi�[��Ϥ_V��賯y��m���@)��+���������a�A�º ��6��誴,sT��A��Q�]N2WR,P}�O@x�6|_{*��>��~����yB��6g]$����r��6M�[�ԖI�%I��!@� �n)v«w�;��ȳ+P��=�����(��Y��f���1�`��{���C��H�	���Y,"h9M�J��;���8�X�1+�*��e�b���u-�"a�&Ma��B=� �|L��,s[c�dFt�.J�b���y3O.���I�zYc�v0��뿞Vȸ}ȗ����;���� �ƶ��&��EV�f���Ĩd��ȳ�Bq9HB`�9�U���wYV�Z��<��:�n+�i�-��D�������ں����>Y���,-Tw�NE xH6�� ��$�׷�J4��i��_�UG����{��I�t�[U���E�/�a�Z�ۈ-���,A����֓i�F�꽷���$�(U�M_�3��k�2�vX�4
�U�g[q�kH��^�[�"��) Q1Z���ڶ���IYf2�X�6�u�>8Д���e������ 	I
D�3���`������c�d��`��={3�]Y���m�赐Md=qđU.� ӕ��f�"��4R|$�_�wqV6s�U�*P��?����S��펛��3�$<�ۮ���/b��HPR�J����H���(���I(���W��vsj.B6[_��V �Qzu�QT,�)��[��Z=���Ņ��
>)��Y '�Km7���r�QIlSwL�8l�\Wy<��
��V@�u�w2���8�զ����Hx�aL��Ys��e#ǐH� �L�u�5`��!���6��97@��ߘf~�wySΘn���Z�ʣ����D����]t7P/����� �N����yRź��� RDB2XK��Q�<��!��6#��i��9�9��-�t��rW�����G$G��+�,���V,xC�"M5/���'�$:J������G||�y?k�O~�>�~��7$�F$�V���?�T�	�r�)�ަ�!��<���N�4��a�q$xW�9�B�a�Yㆢ��aȎ�=߸3ĝ����֤j~��7�8���te�����<͋\���� ��ד �=�!��À*�<z��������ƶ���R�쪌>)x����Խ�'V�Ծzȗ,}�|UP*��w���v���M�����Tp����HSu��D�Vo���3�֊�SUҩ� }a�[`q��E� ��n�����W$
d7����s�rFM�&I�'�KUʵNTD�AZ ڨk�� D^S	R}ź���ԮsY�	��8r�qF��	��-��*���M�g3�5�&��6q�yq���U�A5y���x�D���`�����$\�#���Έ�IQ����o��I�3�S�e"�s}���N    �pj �P�ٝ�5����}�$S1�KI��������]W3tz�2�=jyPۥ\��bX�����&��;�%[@���nCɦ��X1G|�v��pI�r:W1�۞�QmL�n�ц[���� r����>q;�D�.LT6Ll�߁���U�'(�vB�GP@�ﳸ��~qj�D5q�����QĊZkU�R��J-� s�+O���Z��i����|��9ڞ_�����3�.E�%V.�BΤ��g$~�HRh��ek�jqe�>���{�f��}�f���WE��H��L���T5QNG�C�@�����қ.BYV$��8��'0N/^Y�����j萼j�� 6˕�Q�R/��0ѳ�dC���?����i�h�m���zm�����2a	�W��Jr�ԁ��'&�l^��w����tte��gQ�q�*�7
^���h�c�B����`~&��������	�r�m�y��	�[D�y$V��mAj��m�t�.[����z�6�W-���$I�����XPt1���	& ���. UӴ��h�\�=&I�wпX�!%X�b��VpN7g�ؽc�SqHEXѝR�y�8�W���L���U?C��(�2� f�+�:
WF`6���&/"�'���ԧ�nu9�F�ޟ 
�Y�����`�w������-iw=���]�&�_��U��(S��$�~��W����{���3�|!O�la<D�5B��&l:N�i�z9B�O��}������¤�J��<d/I]S����(�Q�ʹ�'5@AЖ�s�i�t3�f�Vŉ�^�{����?!��A��o�����+���&x�Z6Z⻉�-�J�w.032o�W7�k�(ݫ�!
/�P[�@��j���x}���G�&F'ۉ�~y�AƖ������&R��P�����!�#j�K�R��w1� ��Kj[�`i}SE����	pF����˭�}�p���"�4�P}:�x�i���Es�K����p�IK���uJ*4ռ��=^ ��P��Q�w8h󏴬�{<ng�葈Ea��_��M��pqL]�M�I�2ߺ��C��i�y��`n�DDe\����3B��ٜP��#�X�҃Q�]����y�x����][�� 3r�m�M=(���0\��6���\�[����ځx�{}���t��}�V9�ںQ��)9-$y�G��D��O��W�.t�:/�ЕV��L�G�z�*wٞ/�}(� ���j��5��e��Kp1*`�|��̈{�I�(8<�D��>y<G��I}����(S�3�|�VY%�Qj�/X�q�t� �����ݺ��^'�������7z�m��+r^ش�ţo�]��"�g<�Y^)!ue��X����	\	E~�8V����#^wV���ǉ��뜆��"���"jQ�6� O
���F�8���vY�˓%�g���L��e���r�"\K����ə�̬�*�������Q�#-��Ҵ�C*PT4T��J�:�f���"�E��d� �Ճ�#�ш*� JM�-�*�xظz�G��D�i���k��D�������cVXSJ�� � Z'өf��py!A�u�+a�9�DL���cxtH��SS̱�2���	:Ǩd�|}q��ӯ��bn�[�n]��� L��g����r�KP��]��(CJ?l̲�= �S9�����|���oLU!��;��F$^��f7B+�70���tzo�fF���� ��_@����
[`�_H�u������l�ޥ^��I�����!SY��D��u�}�;���E�X�9��J�Y����x�5���j������}��"��Ռγ�m�k�ׂGѻ'�6(!O��>C��OM�"Y�1Q \��w[&iӻ�j��4��P��8w%���)���-i���=�5���~U���I򤜡!P&���lV�dG�-��B��;�C�~l* ��F�F�hP#4��rvWہ�'�>~��dQ���X�����'�o��u���N�tEo��73�h�����.Ne^U3�ǹ΂2�[�zq��=���7ٳ؏������w��� =�ڣ���ob�p�:/0���Ie.��mf���"�u��C�
q�d�"�E�N�sY؍G���5h�k� 
��j5G]3�K�r�F+qϝ�����:��Ta;v��3aDz��U�7�+P��`Ѝ6���o�u�T݌�UV�y���1
V�d8��,b�������Or�w47�ғ���B��>���l�X�EHڼ�ѫ�eU�/Ϣ���j��@lh_#���ns�T4!���@��.�vM:C���Ub4\�7:W�ν�e�^b�wd���YP�̀�_d����i��gP6��Z�m6y���&�����x���Ab^A��@�̬�F-j�z����v[u����dQJ&߈2���7��;\���l\�z$MD�Mʥ@D �^������O���dv��_[}yvd�@����(���S[@�R���:4�Ҵ�e��r�N������j��q����U���w�i��386q�W���R?�iN4/���J�U�X$�X��y���W6�JQM4y������5�@ѺO��)b�����f�e�^T(`(A��Sdp��n�nf���"��m�����0�x�ԓL)����n�]�������U�ߠ�Ecg �m���7E��؛����p]�4�ԋ�|��O�$�2Tď�q���f�����4�ŕ��������F�n���[T`��RDH�}W��?�Y�WY��p�FUOU���M��dbM�Mq�#FϽ����\�:k��C�	z���a��P0U�G�F:�|��l�6��i\�����w��'��^�-(�
���ie��춨<Իp�?L�W����O���e��N�UI��R0��dP�Gm�*�����i��Ռ�Ը�*4��Dow��p���"+��rp-�P���o���Z��E��:b�VٌKY�oAF?�?Ƀ�m��M���qT�BN}Ī�Q��#��.C"dK(����焬*KM�V�ޅ�51[\I��M���Pe�Kc�U!R���l�HYol�*�灚v�a������`Ģ&��$����xx.����_*]9�h�$uy_�(/�������/�5�+�h������	O]���T\}�esBb��DL��+uG���'L�|�#RL����L�o�����ǟ�fqbg��+�/5bi��Z���S�h�"+>�^Sj�c�]�7 �6ߺij&��xܞ�xr��d��p��|+��k�G���ꥦ8���yV�p{�|B=i�������K��f���vO�/�4Ě�S�Q nڷ,�a�^�/���)b0@�� D��w�o�@;�1p��s�R���!���Bw}Z�<j��@ʯ�W���Tb/�#�p�7���&K8�];��Ⲵ2_5Y��k�e��N�'�E^~�Ԇd*�/X-]�B<��'x M,/׺5��A]A]�%K����Q%�߻�� �d���&�z�˗if��,���,U��~=hE|��x�(m�l�C)��H��TV�/��uo&��d��C�,+�v��J�4�Y�1џ��{�b��{���!��!�t�́��:��;ry>�Y�J��ȄÔ�g����a��O�2'/��.�E\���8��H��UVd�^I����J۞��l��+IP���<�<d�|��kV�2���~�BY覊~F	F���P��K����9xA#:@Ae��g(�V����/��7QK�X�0��>7ր��P���c�ވ�LWjQ��M�;늗�dGJD�SX@v,�9veU�Vz�$H���2D	&e�Ȏ�G�vq��P��\ �$���fU��J:�2����?5��ې�ԋ�j� ,�I�"���β��S=!��[� DO��7"����qM�QA��B�z�f����#�V%�L������ ��;C8�j����f(7f�:�:��ȝ0ϧ9CO��p$'��j��^�@�W&�}�`K�E�:ul_������wx� ��o��M��"Cq���[9o�A�5�Y�s��R�;�y8S�>���6j�A�,�L��|�Nײ�    �2�Ê�~���Ix�BAs������h����:˃`��˄o�=������D�����w�a}A��luM�i�kӺYZDz]Q骯Y�X�R�ϝ���o��.*����*�^b�ӱ�z=�F��g�a��\�`D�N���UY$��pe����Ó΅��-���˗]�\��w?�fFF̖Ш7Y3�آ��UY��5� (�^:v�pǓ�hlJ�N4-4K�.���em��vF`�T��%$$����� �3O�W]]��G��g�Ғ���K�%$�.�g�|�*+3Y��e���q�v�A<A�� Y&��qi�U�3EU�@��:�>+��t�ÒX}�l4Z{�1��_Ԗ٤� �q�	Q�:�$��.U�ȧ,��uR�_$�I�����"�H��i�����<������]wR����(J���`��^���W�y���?�il���8�a��.���9d��%���	����G�e�.�@įz�:$Ϫ������Н��~��4c��E���Ȥ�Y���Xȓ�Ρ��g(,xb-PXХ̖�������i%����tD�*%��4zOs>_��@��c���p�>���P*�s�_�)r�_��r��u~��	��κ�NV�2���Q��;��v}�Wӯu�I�[�*}��S^ffN�
8�J����{�\������/0!�Y7eb�q%�����>D���S/����:B��zg	}_'ݞ�sN�u�,_��ގH����)�Ky�_h)J�dO�-��8ݿ��Z�L�7��𖔛�Nd~�Vo�A�V�F1]b��U\���������8�z�Kǐ����h��l��&��?]&)�ղ�Kb�A�@��4UBgr3��\?�*B����s8N�6�)h^5���I�$M�fM�y��l9Y�O�Z:,hb�ϼ�u���1�;)n�0lhЈX_�~��$3ǈ��a��. }����n(��Mb�����.���>�<����.�ۮ?�������4'�fm�w�rşt�F�����ǡ���*tǉ-�Gf�M�A�몕�f�}���V�r��rW�K�x��*[i3=�]�[����m>R f�p\����f6h�b�H�,���Yw�%��7�r!�v������2�]G" �*�^ܡ��z���r� -��j�k� $j�:���@�T� *,RQ�6���t�V�ەI��� ���MZ� $�1�{B��veo� pj��~�c��֨N]�
r�k�{�J�*u+�Hm���J��~@���0ax�Z��_�	ź+�%���Rd}j�ϭIVZ-����|�0ǣ��g���+2PJ<���������A|���*j���H�E��f���+iǪ<��e�:Wإ�#o�i���W{�SX��@�q�� ^Zal�̸�E��l�*�3�+@s�7^��2��v�
��+у��Z ��(뤽����ĚBM�J�u�)9o;ġ�R��`9���$��JAͱo;�G��)l��3^8S��AUFo�mK��j[�/D�_���P;I���r���=:��O��s���?zC�fG�/#x����'d�V{Ȉ�a��^����P���uq�j+d��?�6�[�At���f���ż0�ա�9~s�k�[����+^�O�����p�1a�D�)=�\���%0'&
��>��s}l1&@v����#q?h�u���+5ٳg۸����A�L���{1��ڪ�HJ�	wd�c����WoIY�&i}�N���Gp@�S�]�o�-*$�0��So]�A	�{.SU>�z�X7�#�]�l��wUEo�U�5�d~��=V ��^w�M�ХB虵9�O�`�8n���tmYA�h��Z,�=��h�|��9�l�W�[����C�]�q����,�%6BJ��Ko�!=Q�{���j+����'��}��7��6��S�}K�֋l�QcѶ;5�����Mք4v?j*�5���o7�� �t�����^�_����l�zǕ�o*ˏ]�Ǵ���b���#3���Ѽ"���J��F��1�U�dt�ö��@Ƣ@�0A4`T�yT-��z��eώ�����:"%�p�#D�TB�m#�.��]�����Ӊy��/_�-�q���q��^
�r���g�E߷ٌ��+�2N!�L�:<z�#��#|���sR2(�͟��-�~�gw���=����mr��L��w@p�<�@��}��3�Ӽ��,��.��W�V\��C�\�'p)�N�����&/�fF��,5��]��zx�F%�wj�C�*l��³2�w�I���|u�^�����3��.�`e���g@��8KU�F_�Y�G�P�ڈ�3��� x�������5�+�!^@o��|F�
�)X�rE��&���k0�]bَu�aН���x5����&67#�3�q������c�d��IR#7;��O�\�:j��<���Dţ�?z;W+M27�*k�>���\w��6��e�D�.���_�Ճ ��s�~��.������r�%^�	�hJ�*��'�i���%i���"ԟ#���u7Y��!*��]�d3hH�US�2ɢW�<���9�&��(mli9�Z:���k�b0��0,"�����]�W��I��mO랑�;(]�� �yЕ�w�*�#���h�=N�����w|�q���Xb���w}Y�9=�4G@�K�]�cYN�ǖ�����ᑬ�\��bGR ����9�����\��!T�����0������B��U��a��h��0�<�H;	QO�wG���P��k ��9��	l�ˉ�8}�����$�� �̦� ����(���*�$E�ڋW�z�]�.DT�D9��
��J,��^��vNĪ\*���>QW�D(�5ظ����U�	��?u|#��z/gY^O�7��$-��d>m��D%�Ĺ��*wJbk"��~���p����uO�b#!�Z"F0o5M�4�g�,6QbTF�<<z�C�#�7�"s�2�
Yo����O��o�h��`�L��33#jE�9�d&�HD�6dY��MW\@�"{^�� �:)@��R�%�M�����H{�f�?�q�/l�\���2�dH�@���O�M_3:�,)�T┺�K���/MR�a��v;l���,g<KikZL��N5�U���=v�{`�	�UŸf8�=j�E��'H�*�3v�YjK�0*�4"��ɚD7I�թsY���_D�:��V�qy����}�u{���uT�NF8l@d���#	B�,�Q��p3 &�c癦�_%�i�3^ꬪ�ߢLs_%ծ��¹�^���
��a2E^�L�Fh�8 _�l�R֖3��Yn#
+i���H���.h^� ��t�\NÑ���*�k3��.Ҽҋg�O�p�|���!�H�)���.-�^�
p����*V��*��d&U��2-�w�y�!y��<!���O�ً͒`�D����Ҵ�rɀ � D�X(nN
"�� *���vn�yv�|���F�₠/ �٪�f�eYV��WN������/�>��Z�$���u�l�*�yB��e C�y��/�06e�%݌�fM.�qG��:�j���)k:����~�K&�GYw�cM��'
��R�-��_���QaTE.�Ge�D�К8U 2�ջMfT����_|��aāy�W�L/'�E��V7bNE/%7�6�҄5!�7��G~~�[�$�g�ſ*E��j5�*V{�S���;:$|yp W� "�����.~�S��O�r����ER�i�N��R�:2��xU^@Ί��G�Q��S��?��!�'���-|C�M���/趲��ec������Y��I�� ��l�&h8V�A�8K/Q�^�[ꂸK��B�]�/���$���V�E-�d��z}�B���,�cu]�M Nt�TLܡ�a٧�r{i��q���,w���.8��~�'Z�#~�w�G����r��6D-{�+j1ҮgD�VBw,�"
VKJ�u�;B���4@�����=��^�������+�W�gA�a@r��h?�6MЬ���}���0(89�-�U�G�!�r{��z�]    ��! ��%�c�%�texT
�}[�4�;���{����{(�:�g��=H�o~@��1׵B �����~�B��� ip>w���2�܅�����V0]a�+k+�0����e`���1��3cD��L�;΍�ս.�nZ|����(�|f������"�Kmz�2���/r�΃�UW��nZAd�E�}5%DS���2���j�E�0��AH@L��\�f���l�Ϟ��r��ο��^Nk��,Y�)T�C��@"q������q�i$��z��}��U��7�`#���&xy�4xZyQS��v��"N�į�޴]��͝��b���}#��
�F>�[`UTR��	������������٢e�zN�	�&T��w�Y�S �P��չ>}�����+�D�q����7a�%�x�X0��?ޣ&F��h"�,/@���J���&��SYE�R��j'�3�V�``e��Q��D�K�W9��6���q?��)�X���<�~ǁ7�0�R��"�����79%[x	+w�@���8�zG��@��C쇶��DG���m<q�o"�J��P�]��:AW`����M�p'�^о��U��f���轉(�O��5�o�*1��;E�T��n'��<md��M�B� �$h�t� sH��q4�݂��p�2�d?as,�(�p����B`��lq����w�-�j}�M�X�my�j����,�+��<nM��gur^޺�3�h���=�:<���V��������o�F��&6�&FD���d1b�0�r�����U����t��UN�^���G�܅�9�kӑ��*e��r�"w�sQ��=�L��֘��or�{�DO'�$ZA�~ڡ�S ��ҡiw�`ӫQ���i+����=$VU��(�-T٧)���|���o�NM�*<0U���f�M]�ߜ�> ���#A����_@���:�q�+�$R��Y$
��M�p��	�v�R��)��^�@~��M���Q���z�&Kg���$�����L���bNO��*��RD"UI
R�����w���"�\���(TDe��WL�U���o�/�zGɆ�5d[�S=Ѣ�D*�R3�0)�:ø;w� )*�|Ai#af{�H�'Q�H��PQ��]�S1�W����q�d7�� K��vp��j�>>L�̬�x.������)��5�r<��W��v���)�F����3Ti����)�'���w�b0�đ|���8��9,�L����D�6d�%�l*C�\]q��n`����u`�f)��R�J����k����cKR���o���֎�^b�oK%b��_�TI�̀Fy�[-m���G�^Dm���0��@	F��f����D�r�a\��r����/b���z�y�m.�����	J[6���)����.ɢa����}TZ�����ͫ�-f�?��#�)��˴PK�]O|������nGዠ�&[u|ױ���a��s�
I$b�~u�T <�bc��X���>��|cCS?�����|aO�������&�QX����kY��[r�&��[QS�q��c%�&h�Te��:�ٲ&M��Ȣ?�P�&�6M��7?���Edw���X���U����i_J�Z5D4}��qU��,fQ���P
h��c�vV����v���8/��Mq����]��~L���S]�Bӧ¤���+��!�;/��Ip���+Ps[��0�6�����I��R�&z#�3/�����XW�s:�x�`s�U_|�	�W]l����I! *��k?S�I���R�ab���^,��I�̛��#+��?�>$� b��%4]�͘��f�)�����@kŠV�I�{����c�?x� ��@-���צ��,+K��U�1Ȥa�<n�A�O���Ap _Ƕ�Q���[	�A���2dcW1}�_.M*0M&��NZ��Q;��wª��"׺���um���&v]�3bZ���P&��zE
]�������v�y����z��:���tH�m_�k�J���x��i9�����4�i��C%:?�_x0��V�+%�$�U��o"�!�uO;qv#%wD�ғg���N�:�&�1h�_'�J��7���1ޫO �^�����1<�O�O�� inpw?O�Q�&ݷ���T��H��Ƚt#��-� ����:�~�2U�T)��/\�����?=6�eT�<�>Q���,�l/g/���*���ߕ��7�w���h.���,/�f�Q6����&�����A�qWu����T8������u� �µ�Y�'�����p��;���@.�z�U�&�e����0�'o���.(F�%0�ۄ�>w�o�^"h�+�z��ȃ^v���&f�Ƞ�H����g���+2�+ �J�$KKQ~i<�X�y����D�y�GqF���KfL�Jd6��0h��h#Ըd�4֏�� API_)���ŕ�؃r3BtV9�=>�λ��h�L��}5d� �
��` �宆�{E�]���ߍ�@��	q{��X�3F��U�3�]hx�xڌ,�u�+������]V�F�*4�NK�D�X��N�J�a�(���{��aml9��g�3'ciSF��Z!�ʸ̎�"D��K.N�`T��Bt�����h�6�u�ʺD��XE��(��DN�ޞ_Xq�������h�������{r�����; ����橢|�����QI�KI����SQ����UBN�T'�U�.%q(���0ߞڨis��,�vn`����x ^D���]�����=��)Q��Up	��ys�
EZEv5�]����AY��z�9�>���<�O��Rn5����m��{l���bz���D��E���["Sh����U�9wt���ڔ�ϵ����3zA[Y�@���q0��rJ ���UD���%�t�Ĭ�_r��H*I e�,�4g
v
�rj$�yx�D&G|,�[��*�9��n��~�y�{��X@R���?��q\Z9se}����,Jݫ�K�����E�>�Ǉ��uS΀u��IUa�L�����!<��#�}x�.�'[�j�\B�����$i���2�~�Ie9KA!wR8G���.��qY��_��ujfĥ��j,�zS4�qqR���z���-�Lz���!��SC����[��]*ӬL�k_�k�N%W�Sb�C����PV�<BW%�J���5�U��m�����R_W����a- �]Q�tF�+�Į4�GLcGR��W#� ń@�o��70z�,�_�h��}ff�}�Y�����HxӇq����u'�ŵ��pNֹ�����E�y��'�'�2�+�q��G�� ��zz���(C�(��xd��7�5������uܕu3#�&��NV�>�J�"��0��K<�cX�K�Z���:i����d�JU�q�<�����G�C��yZ}Ƒ���Y��p��ػ+vbG�>dz<S���J���7�qQY-��U��x�R�����_�'��=q]׺�RuX�B�SH�EV���י��T�&��%��Ts z�Z���)�IW
��3�l�\�</fH���C�m�",óNn �d�$�k�Z!�NݞV�k�o]w������+�u���=�����6ww��C-�l�t�( Ee��cY������$�����D�"������f�ߋ��>�S��U�J��p��ݗPr�5@�m��(a�>�K
<�u�H
��y������ �6��xq��u�fM��#ʸ6�[;�)r̲��ʙ����Y@A\V}1���bWK������R2�b�	8��B��R���ƞ ��f[�����Z/�������kЕ���t��Nc�8O�]5����Y�y�'����$�ʮLH�,�p��ز{߇-�X�ڀ��}3#B&�,Y��+��w%'�D�R��=�5 Zñ��U����+�E��!��S�P�Tv���K�u��g�$��C�J�7�I�d��ᅧ3G�*����΅9I��l�(����^7IW��kC������4U�@G�`�    ���V)��A�诒<XM���o+m�O٘WY�_��BMW\(^t1NM��_�1[%�'��ѻ��ƅ{7�(,�Te'��.@9u�V��y�sT�K`��=���j��2L�S��,���G�)��k��V]&�"z�ޛ���\��}���I h��( d���_�Y;|/W�5���3�g���۫��݈��B�Ꞔ_=��{����ignϩHy��A�p p �5qR�3�]^TjrU�޵A0�*<��QGA�ɾ ���5
�e�)�L�������l��Z�v�_+�
���9�mɑN%���=��nG��+���?z<u'��_�Qʗ�'|g��!��o�ބ�:�BU7�����vT��Q�?�=���
*���D)�\�A� 9����8�(�(�#}"��vƂ�Z�H2�tU�C���]C{p� l�>���l��4��~���(
Ri8{l���HIp*�(U���1w��zi�MQ]�(C�`��$����`S��U��]�7��H�91�*�jH�q/&P��&����O�|��h��_�h6iU� Y�f��߈<�01W�,��^Uܮ`��d�/����%����?:���7��~?O/�w�pȧ���S�l���������-��H$rh�\/�4�&�M��+��IM&PE w��^��Z@f?�&`V&ªɏOmo`��Ɍ��t1�%�Y��3��N`�y�:�+j�mx�~%��01P���-3Z�me��z?Dt,���zFV�y�J@A�H��e]->�W��(��L�>�����U!'��!u��lo�iL;�ڪCЏ�=m\}�=�y�,!Ԓ�Ƚb�Όb�tz����P������tS�q6������Sg�/h:���{C�Y������	��+�>P�� ث 	�@���՝g`{T^r�)�>�~�)��*�	VZ��E�0��� �y�=�o��Q$��� z��'� ���B��<ȥ�L�:`�$C�E��i �����]=��%PB�R���Z�R���e:��Xe���*ĿC�BΦ� ���kk���{C��O��=��]��dc�����Vq\�F��e�3�>�S����(��a�s���Y :���~��OaKM�6�l��X��L!z��4*Q��u��\w�2T�}[�D4��������H�B��]�3eS'���T�$�W?U��>�,�y��:�$�c�+�}~��^� NI*�����B<?*x
(�xgŤ��!Z���`p���(����
�׹ޙ�%��Wj7=�KH�� h�"�q4��v�'��A�?t�h�5(�SaP���.�\�j钲�	�B�M��xc_���G� Y���+ˡ�>��$;B�E<���#���5����V��w����,�f\X�$�>��y!�-;� &"r�{�i<B��uլ�z�(�J�B��$q)#T�|�,�돈����/��K��6~�ؓ���/�|5u��8_�ս�M@�����QW>Wa����ZȋHЍ�cЪX�j�,����ڍ� |/A��1�u�������Es�y�N�d�o2���Y|w��0ݮ�'T،�Hڅ
>8��x0���f��H�U�J���=8���[���r��i�������*R�?hP��_��j����|��HLnuW#r�X� i[�=���w�O���L��z{/*k�s@�����h�z/�)Z�и�s���{���?U�E��H��x�*����L�� ��K��1���D��_x��dJ��z!��[L�jG�!h��D�;Q��x�N$���>�gsWy��2)�W.��C�>�[0�<t��+qF�V3�w��Q�q��i_���s3���+k�4��۝��b��EX���;��sYF}m�S���:kdl
��Х�@���,_%�u���E���H��)�?Ԃ��	z���\:&p�E�G�RE�~��вȮ@��L@߉.��/A��6�
��
�q���+x��x�W�)�����=ś�u����FZp�8��Z��T��o�\#�N��Dua�����7����'U�cx��;�'Ok�\L�f"�i�;�Ɇ��|�O�K�]�q���� :=N�t�M<�O�pJ�n��,g�RWF��ކ����P� ��:b�HG!w`�=W��AG9��Z͈[���d��u2'n&����
؅r�4���ⲻ�}qOT�?�h�G�GbO���m�7��+�
$}i��8�0){�n��{ ��욮��xzbD�?��E�q�����*��Ų,E��� �!���Ԧ�1�A¡F�����/mh���O��g�m������f:�I��=٧�����0���!�����3l��H�N��Z���Vti5�}������VZ�w}��N�8��:��ݰ@h�5n�l=�k��J��Kh��u׮n(�x�jG�7��|�^MG�r����CĲ�W�omm;s�8^\�$˴��	pK�Cdi9���&{�-hpC��yL	��N��9*]K�IkNQ#����R�|G�N��!!��Jl��f���mbl?J�	_.�g��`#�>@E:A�B�Rr��=��IpQ�"Xq%�ڠ�q�YR�pM��X?�f=X4��;&.=����fAOa,d:��> �t*Ӫ	�`E�m$V�;��&ao�����G��F�����?=^N��{p��%�����[횗���o� �x�+�C{�Y����#�<_@������_��-��^��ڴ��G5uo�L��2MaA���z�DNXe���~|,Mۦy9�g��5�X`�`L�����jt���'²�eo�U��.,����V����m�V�ױ~8�/�\���o_��.]@o��q^5�ǭ(JQ�Y2����^��dK�v�`�,ng�Hp$K7̖h��]�U2�c~�d(z���] :�Kʬ�q,M�X)��$�I�v�اGFj���b`�nɜW"����>[�f�K��nW&�2��
!��+�k���0W�t�2�^�	���`�Y3V��늦�f�FW��&+�#1a�;�ګ1B�_"��9%m pڼ1��=~�޹;g�Rg��-٬��ܜ�|芥iZ��U�'6.@�ʲM��Т�F�="՘Co;�P�m�cTF�^�Q�+l�0�V��+���T�d�1�S i)��5��"��G�|��kݑ`]:�"{��� ��o�m�)�V0���B胠 �e�����Z�o"2��*?w������L<��oV/�������ۺ�[�̝�$-�-3��q����O��7<_�j�Ycݚ-�o�s����4�D��f%L+��:����/
�A��# ="qL�<��w J�mA�aD���������$K21������'������o<�_���ft�������b��6�7��D�<���O@b���3)�
��ґXp��㵥�͡FE�)_��҇p��֮l��w�I��y	ni�U�P�-u�`*�?�Q�Η�*r��G�� iFL��޾k�/`Q�.��wD�M���&&p�ObCJ�j���<�'ikg�:S��y���c�l�TF(6D���;+���՚L�	����%K[�����2�U�g�pM�Z`d�������6��:\N/"W��o�y���W�&UV5B�1=>�O�z�
")mRIF����ぬ!x�m��C
�����a<�~�Ϫ��h�T)/�7��&�V��	�>�R��a ���I�'tL��D�]wc����4s�9��O���D�k�Q*���.�^�x�3�p�V��ؐ��V<ꚿ���C=V�R�&�����������������e�J�<B�DC��z0�h�t 킏b��$E:�Hvw]�4��^��N������q�s?����œz٢��G�8DiZ��lr�Ҹp��D��~#�; ]ȸv����,N ���4�P������T�'�4�sE��膘M�7>���'��@�`Խ+ő�+��q�0���yC���[['�0D]$��    �+Z��?�?�S��b��ð�+�M!�Yrgo�%�NH;���"F1� �%{l�Ղ���.�?�׽w��p@�
�D�.�$�.$�˞���Y�@�gQ��(�`�Ja��/F'_�Z1�W`�"���q�
ϨN.7v�A���[&�"^�J�|������*����	C�3g��� `�	nxJ ֝�m�A��Pm�}�X�'V�X�]z_��������X��/��ʲ��c����g�+Ǝ���j}��_e��Z�X��g_�릛WSh�Xd�Ϡ��9s�*�ҫ�I��$�B\�M
Q$�b	m\ݷՌ�5K*Es�KP��H&��F�Э���hfĠL�	_@X߷��XuO?!� ��l6ϒ%v���!6�E���Tyq�t.��L��k�64辩�*��8B戓C�3_\f��5�"��[k�j�S����E�D1R� �$���%I�aO���6��J�;P��X�m�!�K�G	���fW?��oJj�j}zQ�����I�J]�?d;�d&�<$�Cb�ڜ0d|��֔�<n2�1;
:��R��pe]���	��V.n&:q��&���h18�	d���g�<�֡�����Y*�\Q���>��%�.~L�",���*ݽb����rؒFT�������g4\E�����~g���^�ZQP�����_�v��K�^xl8�p�i*K;����O�6(�6��$��jp�1FL<�{�g��;����?�_����]�Kd�	2�ȇkp"WE���¡4u�B�@ޚJ	�:�۴�V�A�	��1�����&������ߞ�U�p=A�^��}O�Oeۍ�[�>8���Q�I'Y;�0�"�k��;��+r����w������)�3"��b������c��L���N\8]�9��+cw8$�I�"��ݗ,�����~ Z�>�'#M�3� ��؞�����4��
f|<�3T�S_H�	r�4�N]�ɔ"~�*�f��D�u~��_2�e� ���H��2
���k^F� d3-*�������a��5�(p�dkQ�	Z�"�l��>�B�$��IYpALAd��'���^�}_���jaJ?�<|��I��=����/�F?�J�;�e�d0:��� J�ꒆ���/v���,��u�͸�6M��o����LJy3�_�[4�X�	#
tdAD,}x���(�����0O�KZ9��.p�Ǒ?1ȉ��؎"<�������)��}�ؾM��/�m��7�2�R��ߥgq����gtc�T��ɣ?(��2D��aP6�ܢN]W��RLHt����v��3_��Uz�� @u���*��oѼPD<9�u�݉r�°�+IE��~�sw�?�G;����x�r/��ζ�B�Rv�4X��� 6,2��hc���D����%�
(����h���2�H͇��f�i-)fz�n[5��������	I3[�|�*z�����c�'~��8ϫ|���ݖB+��]r�8q�hu#��b*���s���d8#$���<I\$f2���@Zc��0;�_X��퇉ڨju
�b��/ �]�ݏ��LE�L���ch4�K�Fz2�a�J�:�5m+�%�s�½���u9c6�Ŷ���џ��*="1���;dt���C%TD�|�eW��E��Β<V���">0ApR��C
6��?�m�(
_(�x�ѓk���F�|!���?Nb[�Ō�骤\��2�>�pQ�EF}(�1s� x)B8�	�7�G�r�,�nVI[ψ������$z;�����-(y��� _~PQwD7��uf����?���Ū��w,^e�~Ζ��u���������A �[�'Y�ͫ�v�;��^���"1�507�$3�:�[\C��qs��^���Ķ�FKp���_BF�@��ʤ��yD7]@t�63��fY'FO_�H��;�P>S�͓;��*E��x��t7yog$μ���,�w�V����AOO��7��&wĝ&�ǾP�Q5v������.���^��ߦI}���UE��D�\8�D8���Z����P|+�*;N�P"XEQX�X�]l�~�)+L����~&3	�8Q?[G( ����ͼ��|����p�� x��oIܭ���$Y�w�F�������Ճm�+�\�vYl��yu4��z}��\�5�m3C�&3ƨy^YE�L�Q��2E��`kވ=a�[�<E����ם����Lc+����w������ό&�~���ԋ ��&�{��	BV=~U�$�z�*PV�e,�u�D��=�R�o����A�^�Ӳ!���b�[�6��nv8�X�_�>V'jO��L�ebVWv����(w��4 q�����J#8��#3W�H��bLR!��Sx"���{�B�L�Ϩ����N�J�����g�yD��@׿D�]�q�=zoj�0l����&qv�B?���B�,��h�Z ��� K'�WtAW�y��Mu#�T�Z�&Z�e�B����ו3�~2k�b�f���x�`~������G��j��9�ZP1j/�����M��O�&�eʪ\i�6����Q��G�H�J�k,��S}>�x�y^%�XU��m}\���Z,�1����'U��	d�yV�ro��"Ή�/�$-@\z�ll��Z��(���F3��R�3��ğ���]��!�j��Q@�0QnbN���HQ��pd0�[�F�[����S�Ĥ͌��}�q.'[B��H[��1��dsVո`�,,D:?tV�S�z"�f����9yRd���T��]}Ý+�E}���s�|ܜǻ��'R�����ǲ�4R6e}�Ӹ�͔����#܌1]��	*`��vyw�v�h�dB����$���fF��J�*��&�� 
u.w�#�� a��
�r��R��5��2&�(W���$�4��>!=�ޑ� �ܑJ	i/����@I����ӟ�Βv�{����'�����#�LF _�1I�i��8#yjTn�ʢO�q���I��o���Ү��^�UR!��%������'mˏd�'m:#h���T�Z�tqǃ� p���'L{ J>��8�wꃰ����7���h��@�^�����WMS���sW5�d�*�_.(�1���$%��"�jש���؝��+�����q��n�ğJ��Y�a�i��(�ϷU���uE�d����������!v����6k����i���வ0�U�E�����(�L�:�4m��>���A��Tav��o����dZ�|v�����w-[ a���ȵ�����|��0�@!��]'�«�A	���#;���宱���B�����^r�.b�TB���?sSZ� Xi#�i��=��_G�Ai�m���og�샭ﾩ�[�:^�I~|��(�r�ޏ�N�X�?W�D��FQ�%_	RDi�`�B�aۆ�P��1T6nlo�G �U�w����P']i�ϩ��X�*��ůP��5�R�{,�q�7��pe�G�������$,
�k�5�lRo��>�_��a/��8Ҥ��1Fc2��TbJ���ê���H鶁����5L6�7��҄u�;-�R�C_}�+2�hA�����O���.�����y��k�I>�dޅ�x����D˔�X*�"�UC�L0~�_�)�h��ES��W;:�{	v�&Yo�Y@����zF�e*k_3���Y�<��\���ɧyF؉��x�'j4�<r�Q��9�WJ�OsG��Fh��M��f����g��"�K�P�3/�'�u$���e�LdKM�b� �(�]f�k�61�V���G�^J����r:�6	\x�#��
��%��B��*�E$�j�F�҆>�l��fW�7ɭ���S�I�^�۩����3����ȹ�/ "�:if��*�*N�7jp����=W��RE��Y"�g�a�R�4�ŵ�E����/y�t�ճ^�����̵<�o��G{/;��N��< ��I~��M����d��\y$��3%��ڀZ�t-im��-�.�3�R�'�ΟI#��ǽǹ�%|(�)���")��H���D�,�oDw����s    �{�L ������ҲN���%E�}�M�J4 <��$T���d.��0 �!��gV�bf��sV,�ܰ6��NTdqZ$�2��W�߱s��s�r9bb�6��z>� {:��ѕ�_���~�T��
}�l��	q�����gv__�f��S���N� 9�z�h��P��IA�C�N`��iBW��t�'t�^�}�uZws��P�*�����*�}s�����[azuu?���x�IP
�0��{E$�zm��V��z�$�IɦXa��R\�=	lT='8IX?�$]�7p���NG?ݫ@m9jn+�RT4��Y=�3ml;�D��Đ@�d8�̯3rQ�XyO��	�P���ę�EJ{�����i0�b��k�s&J�I*+[�E�d�H�A�s&w����9ym�W0Vo���c��bz���sh)�F���Q�vY;��Φw�
�&
�����_3>Pށ. U�K7	�N�ƙ3�������8/=����i>��}M9�\P��?�E��k	��%��C��<QC��`M�7�p_�1�-�9 ��!�1�3��Ŭ��&��8w���σ��G������,)�.����4� ��o7-��m�\� <f���y�.5K�dNFp�@ Ub�W[at�%���\s9-�D�8��>h��t�B;��,ϒ��&.�R�$x�}��ŀH�paQU]�����&!bSR/�~_k��b�&.�"S��e���7�$E�mFG?_���=�<����VM(���m�9�D�����zl���?�p/5��;�b=�z�j>�V�_3g����e�I3E�Ui�3ݿ�~�vCs��=O���!(�5�M���A+�1Qǚ����T�9mO��OeeW��'�%F�U��FK�����u����e��	O곹����'�{�����k�Ь�*K���}l�f�Z*�6"Xh~�N�	W�az�bE�U��%:���!$Y����7wo�Tli�`
b�����8/V�*���Y�TO�_��B��l�k����4��2��c�"z˭��'��"�;W��Tõ�b[W�fbsY��3�j�Y���D��¤���ӥu���I�%�"=S�����Pv&"}lc_���o��'���g�OP�5�:��ÆW]�8���2����Jԙ\��?tM��(�]Pr�� ���Al"��Y�Lq����� ���i+���y�>)B��&�����危I��*S��6�b�8Y��=�h]��̟M��F�zF����<6��u[�R�A�bw�l�	.�>� �Tv���1�L�G@��_"|�xU�O��]�����Y�j�*7&�|�hw�����9�/vP�2
>���U��W̙��C}��5�?��i�U3�aec��ei�S���	k��'ǯ;�6�����]�eL�՝�G!�J�u%�N�,������/��E��G���Sq�e�� �ܜO�.���e�]���z�Z�'NЀT��-�Wȳ���(^�U�X�,�F*d͹�������3�N�hؚ"<��F�3�2)�R�LYyJBQ�.�����B�JB�6�����1݌�L�4�Df�wB�B�"/���y���<wF�L:���޹��ñ�L�1��;H�C6�i�a?!fѵD(�����WP�/�η�y�iO^�lƌ��K�d6z���Ym��.=~�,F�|� 0������jT��e����	R�[Z� E~r����"$\�,Y���� �D���Y������fG��6��-���R4`��O��uH\yĖ��^�Y4��=tV��3Ů~���%����B����:�\�	�Ե���z� >�`gwRoʤ�)+P��}<C��,L�OY�tK����%�-JL���]���O!�0�}<�5I9���ɛ8ng\U]}1�#qm�r�s�tMh�G�����'�5�(Hߺd�D�gU=#bU�jĒ��~{��z���A�!�SЏ��7�-� m;lG�e��N����Gqr�t��
Q?v^`X��`G-���%V{����_�@4����H��$D)֘r4�:�@����iա��-�VҿG���W��M�	�����&�Sp����>s�˨���{��(//\pȻ��O1�jQ3���!8X8b�M%"�">�%��� ��U�������"�d����۱�~�m��~@Y���4zu���(�|�v���B�<�-v��aO�6�����j�>xDn��yW�3�7eYY]2�Y$��2��m@���T��SwJ��c�/S�r|/[.�.]@�ћ|N��E�� %����{�p#0�ÞG�{��/�s+����|�!��g�m�*�siN�"z�lQ���jOԬ[�!S"���8�o����ypEg3��˪���ܸR�U4�W��;3g��QskM�'���z|m	��(���m�ľ�)�t7��3�x�|�>\���U��"d �h-��-Һ�ahfc�瑹��z�n�e��|�(�I~�Id��)���ؘ"�mu�B�&i�H��8�؎B�C淬yar+n}��y9q/���g�%�D4uE������f��HWVȴ���W��ZA��R Oz��˖<]����EQV���M��U���?���K�Q��8Ql�C�ާKCEzrǽ!	�q�Rv0�_��rrN}���B�)r��7b��/iE`*�_��#��8���H毢��>R|��:r_�Ң��0zA�������DQE]=�(%�:���M?Z�ѻl�A�:N=F�J9jA�T���2��VG�T��=ƀ|�����x��~��~a���͒,�9z�F��Q�����ة��+���f�4�u$���+.w�<>P�(�9=��J�K*����5��v\.�qS!��>��|���������c�0p䬩g4R�u"Vy��>o�+��t��`�-�r?�N�\��y}���q�`���bsx��>�D���tƁ,R�k%�U5(�+
l�9�{j�]N~ŏ-"T�0�F���ݺ)�o^QYe��3_�]"��D�q:�7l1�o�9!rhș�ه15���@�Hq�+��_.�<~K���kc�,��SJ3[��Ɠ@7�T�DD�o��",D+w)g��Lm��1� �#E	SKh��	��joj�u�Ge��XR�&��/{��e�ݛ�'R�C$ar��Ӌ;��鷾�v�-Mȹ��[w���Tyǜ�����F>�����������$�u����4H�0����� D	d���]y���sR N/"����+Ts�8W_ ;r�A��JL"��GL�}q��n,ں,f���Z����|���Ʉ�����~�!:�	D�8���S{Z��tt,"��b&�:_�_��9�I�u�D���<S��?�A@M�.>������I�5���Bc�tv�c,C|������ݬ��,��i�P�[?RN7��6�Zӫ�D��R�G#�^^���~�$U���X��B�R�h���VN�ko#��$�!�;�-���X�^X;��h���,`Vڭ�@k+�Q����b�<�QcSs(1��e��k��K���Z+�6 %=�!k-����*��V��"�����Ry?�D��o�vfޣ�����C�s�@�삂FE���	���:&�M6c]���0i��SpEB��
E``�'O�hD��>|�I��}��[��r��Ȫ%6�� ��.�JO!�1���v��E6�Ra�%3|�Ş�83�M���(�lS&�7fU����d�G�R��`w-�ǰ��/���<�e+Mq*�ڼ�t�:�Ng�8���Oó�Um)d@�9��A�O=M%HK�����U�/�J놄��w�ɹ�濔�?�3�]��CK��m�F�i��%�/�"&�:� ��"@G��p ������?�?������@ �v�8]Ov�1�j0rXσ���kz�\�9��xݩ
>p�,[Y��YA?N�%Ј�3~\���W"&��"�qZm��A�r��MTKPWm�0O��(E�f<Bv���Fu�R�Z���eq�޿���̪`�)�7�y�U    S��N�<�E�
r.���!H¦R�K���Rb�T�d��y�����v��G��7�k�s�.����.�c�Vѳ{�k��w�<G0��(p�9 ����Kt��0����L�6fƭNsΘ2�taq��-b|D�Ս�eL5� w�9�ɽǰzA��q��E�44�^�c�轻�N�IיŦ�ےmIim��9�F�p=���r*tDh��4���p��s*G�$'N;���'��1���+�1�P1��c� *��)���HO�b\3��p��� n��3�ĭ��U��V�+�@�w��9Ђ�!K/�?����w�2�W�ļ�w� V�t��7�T �z��)l��'��T��Xq���	��*�F3jt�τ�b�E��F�rM�)������T��T��at�A|�+�ѯ/�h�� �����mǍ#��η�y>\J�e{ڲ5-M�&���b�E��r������I��D��=��R�fĎ}X���Y?�=�d�%��;@��U6Ed�ɓ��6Ul����{>P��'�t�u�_�E�Z#����yшd3��ؠ>�ϧ58�f| ������= �M��Q0Jg��v/�aP��7�ۋ�8Y�ǃ�/A�4�z�Y�A�#�q��@��O(�y��7�D���Dk�\xs���C��a�ǃg��N�f�����%#}�fj�#��{��
Dv�-sO��I@"V��/e&�W#��`H~�/T�.�� �I5%w�ec�@U�5���������|���ų��n��ص�u�ȹ��&�L�����TiG;�Oę�w�XX�|���Ӂ�v��������=��iZg�������I��L�M����v�#�މ&��+[P�}m�(x�N��>���&1�0@�Z&�� �ܛ�����f�9��p�����cfq�ߦ�L��΋�f�-G��f�2O�1i]��&9���'��E������2��������w�c/�?��ß+��/X#�x�~|D�N�<�?<���t>�׬��/�P6]5���)�&�ʢ�жR��$�%�~�Z�J`^:�k��"X	�t�1{� �F�4��ב,�3���{��M9��ޔY�����5�[.�Ϯ꼓���V�A\����g��d~��"s���PX���޶[VfH������kw&�޲.mPPĜ���lX@�m[Z>~kǚ��S~���Wk��$��P�Pvy:L�ZUy��2���X4��-��`Q4����a�L�ꏺ�z�pď����B�M<h'+�P���x��9��О(=�/|��Ͻ^�>���v�������`:a�,���B�x���0��II�MT���0��c��퍇2��Q�rn�z�|���~�!ۧ�V޷l�N���+>��ė3�y_cM���QF�+*�A�<���v�>�Ҩ�L2.齵���W������� U�d�>��	��:�M^��.�(�H�܎}�>E��GLM�?=�LYJ9r�bC޴U�J��S��A-��Rw��f���2�!׫:�X���/�!w/��k���e}Ã���!�sYU��Xu���ڸ����!�E��JXp�~����$�/.AIb���C��5� ��n6����b[��Ä&��s[���M�xoDU�Э��	&W,����
�$�	�l�G��j�������FF��q�m3��ā�,�|)����{��}!�����˯V�/� ���s������q�v9���8~���jۣ���훮�o��z�#W�/��Є9��]�7+�=��12�-��R� �O�pm���P�bi@y"��@��73 �V���$����A�{~Xn����+xi�klsg"-��˟�WiW��/�"�Ty�~�N��:� �P�]�h@suW�/��Ǐ n*4�w�<���Ф���Y7�񤜩�!j0����TE�o�ۣ�����y��Ǚ�Z7�5'��9y��������!h߁R\U�iZ������A�B�W��)h�.*$&`p��x�&��B��!Rx��v���MU�E:!#�sP��(�3�;�	E.����T������LR��u%�A
�pp5�\;����`�\��]>�vUef�]��f�=
���#@R��F��.gC�cJ�#�l��w�<��l�M8Fu���ƛ�wv4ظ���I�P ��G0�H��[�����B����0�����)M����0���%�'�lߞ=E� !X�� 0��1�yi�9cܠQbep5���<�Y������Kg�D��/�E~M�?($q2��fӫ-S��.��r�y����T�FVN�<.���$@s�''}�@϶�&�Z���7*B�B�a�F�ԑ�}?Ab?��x}u\���|������J������d���Ʋ����Y�t~&���Մ�c�ϗ?k�Ӥ\��GɅ��^�,��)�[A�Q�y?G��1,�m?{̵���29o�ְ�7����D8��T`��X�l�V�Rn*j��X	W�ª=�N�9�:���׃�7�I8+&�W�]<p���d��*9�R��#�v���u�ʠj��������	��XʎI���t�8s�����/�3��E��m8v���@Z�v�����&�28v�E���n�w�W��P�M��6�T��x�>���I�ul]$���Z.jYU�4y�����R�5G�N��A xKr��\��]
�� TY�{��-�Į�zЗ�|��Ŝ^k�K���8@��a7�ˏ҂��5�� ��[�, 2�苔��NTAoj�������$M#~������y��Z�_F�G�
�f�^�>���Fp�x�o�f�Dsd�jBH�w�w�j�g�������)N�w��M3�>�H�0��������ݡ��2��'���^�b��~N��{c6�^�"H��R|W�N�a��/���ZF��
��
r1
����\_�����xA�#R��G��ͺ�n�}$e[�����E���U�8�h�{dD��Iƌp-D����u�êN��������o��ĩ�i~Ch�#���>s����%_�.����MDZ�w�~�vu��\B�D_�5:q�Y.�[v����|��cH̒g3V{ P�����W�.'�����t�6����;��18R=E,��bS���%8���0*��BU��d�v-�@�;O�Y��b媥��^��ƖkʍƷ��cE��zmbXp^��J�uq9��Um*_M}t=����S>��o9f��aK=��p��%i�Z��?�;�1bu�+.��Su�)��s� ���������u<���*y��GI��[$=vf�����R2��T��0t��鷳�:/���x�����&��c#�һ�ݐԷwhE��a�i�3D�HQ�,�#�M��/�j��q��Bvo�!ig��Pm�ۋ�"�j��Y�����^4�߹�]��Շ��
x�Hw� 0��	�qG���~��O���Z���s������\(���wy����q�o��G?��ǽߘ�&Ei��r���z�����:�Y�\R��ҋ�8.h����m>jU�*%ñ� �yx6Y��\9�pʹ�o����Y�4���aŏi��%_J���6CW��,-�	�7�3e�2�N[?�@��םa�hh�)w�i�͢����>�p��Ι̪hT\3�ӫ��|Lѥ��}�5��H�g���ͫ��N�?����yRVY��EY�1��u��XB��pA�WL'���`�
���ݮ=���6������,Q�}�,_�{cw�9��
��(���:�qb�Ǚr��jꫨ^�}���f]�Κki���h�jJ9#���4��k�c�c̱�v������oE`��q�G����$;YWn@h��:[�}8�TkÔN��t�3�7�Կ�Rg����L�PQs�ru�z�s��q3#� �pI�5q12:�P��WApQ�
t�ð����1����~�>�G"����[X=i��Q�	VzY#zw�����'�w    F��	��i�.6^��K6M3O�\�]r{/Q�R䑆^�l`�@z)�3e��eK�Œ-OP	��1�dċ}��k�Y���݄�v�x*n�F5��h�GTq�P�kA,9��Fpi.@��a3�Mz�ՠP�6��$���p�K�@W�ė����ʻq��Mۯ�T$0��e<n�@�	_KV|�K`�%�l���<����m����e�����..g�_Nk�73�9y+u)W�@����I��J�E��û���7���{)+A�^ ��Z�����[�}[�k�4�ßf�-����յg��1
7@d�s��f���P���aX� \{��ǂ��t��[f�n����m�ݾ�)��ִ)�~��TMj�C���7��Ʒ�m��B�u�L��|�@W-u�L��y��CRD�r�<֯�-nxF���;��?ے��V�}�|��0N�a��em7~X�S�+���:��U��e�QB�K�k' )��'�ߦ
��d���_��'�iZ��uw��gg�V��!��d��J��0��jio鹣�%}?]��[�q� �ّ�亽�e���Evk6�LtAM�L�U�ܺr�,scry��W�߯4���z9��2yg�E��R��E^ķ��J��������7��;����kN���B��X����QS@z�H`�N�q�vE�-Z�ؿ�VBhfd4rBIC�j�V�7?
	����i?`�mln�9d�mG�Q�*�����\��g��6����nD�j������1��#c!*�D"̇{��3._ܟ�@g�b�X��&uOSs�d(Z������ek[��z__;�.>���K��R��m��<㬾�6��R��RM��:2��!�K��֨H���5��(� ݂SP}�R��/�>^,~s弤��.�P��i#XmҘ٬��,̃������k�z�j���M:�t�o�d²�l�BI��G�n��Wz��ć���_��:z����(�	d+յo�B�4x@m�sQm�zZ��Y��.o��U�U��i}��#�9\��p���*�&��z%�b��)��ժJ��Ez^��m�J�q_m�Ƣ��	�*1��4�(.z|�&�!	�#U�*�}�O?�M
��� 	�>����fh�~��th���7�JsW�1nYd
���k��'������:��:�����*]�q���1mo_oTY�JB$ͣ�Y����U7�qV�*6H��ɋw���2-4�x�j,"b�� s�.D����_�qWo�r��cS��Y����j���sc���kl)�x�y 8�k= ���7��5��	J�ņJy]5�Ƭ�]��E�(Ru_i}d�l���B��}��%��L$�Jz�0���鏯�\{�<�� DI�߂Q�Ɏy2���,@>ȏ���~��z(L�w,F��6W"�(L�l�Iߏ�lupe͊�%���DB�dlvZs�E�J݁I�Pk辌Ht�����}g��%�U7]߯���t'��?V��2E��3�;��������Ϛ	���<�h���ڠ�����b2����4-�Vf+�(&���*7����>j��e�^��[���QL��r`?�� ��EO>�B�j�i�O4�H���l��b��?�����D�������_���
�8j��j�xi<{�'0�V����ᶯ����x�).v�݇���6EU�>}v]Q��������5��<�����A�/���J�zJ�$�F�_���'�Xy3��~h������q^i �%�/{߇9��tώ�g^�⋊yH�8(�%��Q� ^ƙHS�)�ݿQ܄��u��5X1��.�EпF�p��wpymF<��HQ�� ��&j��b�;$,`�<)܏<c=7�ȅV[�1g���q�� �sϰ=~M�"fe����w5r%�j3�f�*d\t>n��S
;��Z���6���+w���w��*�n��I�H�"K�O��2���OG�g��ݻ��U?ܱ�A��g�}ܱ_l�5�m�6�����\/M�E���������'��뱂�-q�]����t>�rI����������p�$��6Ŧ�����"U����wE�?1R	��Q��H���*��O�����I�"�}�T��d���.����?k[���[�\�˪����f5Y����J�{jq��m��dS�q;K�-�Yf\���&`�뢨$��f�;p����{ɦ�c h���l�3�(�z�s�ka��' &Ԛm,�%��)�Xx�OA��Nf=��0}L@:"]WO�aV�$a1,_���z�#����+a+�������b"���(c����=��M3���ϝ����/"b����w�>�t���y�i����-� ���!dC��(ni�,�4ǽ��WLTcG��ݡ]�{n�>�fy�7y�M���2���T�{_��ϊO7<B���zF{�3<m��{��R�-��y�K������G0C�T���{=�#�)����5��NW-^G?��4���c\����~�]RUMJ$��#BKު\�!�]������+f�\��_g�D�*�	"^u]�*k�wD�Rk�\�:���f�_<h�P��і�2�]K��H���Y�r~�Ǌ� 9�a����X�3[�����]�\x�2Kń���8mbv{�8o)C`�WߦCi�M
�[�B���Z�X�ٮC$A?�w��G��5���ن@��(��g��@�y�]7["�^�Z�`iGIo���_�d��c���,��M����&������ǀ��k�w��=]qnN�|x���Ǌ�^�ȩ!9�v��`��6@��#���k�O�-����q�l��-����<������Fc*������S���
C��G}�7���<�@9��Lgsw;l��a�Tr��w����u�{u����F��`Ÿ�w��%���B����f�@.��P�m͔�د��Fz���yt��xEs� �}K�`���������)��&�'��B�<�Y����f
FF�l&��	>�s���̶Ċ��yX[�JӴj���*z����JՏ� o���'� @����Nw���i	�y��,d��g6PSZ����.\�e��Ѹ5��w�N����� �w�����F%���f~N�ԫ;c�=i{}�dE.�C�!�.w���*�،�G��Us;�����ˠ�f�96+��f��I���֬
On��j�jW�]���Y�kNHZ+�(%	z�����t4r6��[��N���ܿ ����7���W��A-���8q眕�pw������}{4�ͳ��(a�kۮ2�f���r�f�ya��`*k.�ۭ��O�#s�1[Z7�$�c���ǶM�U�ȋ�g{��j1O�z"j�Xs�Փ��͢@
���v����l�1�~҄7�H�X�u)�j�I<��Ý��O"����ڜ5D���)]��ZkŐծ�E�Xj,9[=�"�e�P�2���>��H�g�(��Tv�#5V��2��K�Qb2/_<*6��!�&\]��)^u��~v-��ЅB�#�v�����mkOҝ�	�j�vo.�S\�ɔ�*Je�ƅO������������<:9(���FP.�˅g���L�	2WM�%�\q���wI���C��������x
�%�&��\��)��faz���M�4I�]g�D��c�%��X��lNڰ�"�;��0E=zv�nRc��9>]zW2�\"+�Ő��%�&I6����+]2��E��z�R�U��F��Q���%V��O���_0��<Y�Ug�Wn��M)8��a��Du)`�&�����j���`^d����z�8
���%�W� nc�����1�I<�k����ո4>�ؒ��	���`8YK@�}�I�2\��?�/��G��b+��c�5�-��)�2��u,X��J��x��.�
���h�l�3N�d�E����|N�LU�O�0񧯎�$9U�/G��� �� ���΅q1d�l��4^yQ��� �E�Gh�P0�]B;�W�W�߿���d�m��;�I���-�מ/A�iw3�	ak������>O��	A��� ��*@8)�
|x�*=�}�T3��4B�j�    �=��rJxs-��x(�f�=���$,XF�Nvp5���/����61���y�ڏ���_O�Mݬ',�넸�����{�Ov�ہ�u�A��m�e�q�JfuZ���\����6tikS���"k2U�u�APY���ir�ZԖDA˫��2Dp؀�@��N�7WJ�r�pЋ��K�4M�	oH����h`׆
�/^BZ��p4�A~�z�S�]�}�P�E�^j:�N�$���eE_�"Ք�ɕq�!��U�گ�.���q�GUg[�Ii=��W��w�u8%��O�06����)fy'���	�IU�b��؟��I����|e�l�Ssa�-�mj��ڇ��vP����������EoL�b="Y���i�X��%\h��3C��~�KpQl[��.Z�bњ��U��j�&���J�=�R�y��������͇��`��l\��@�3Xl,?�*ܽ�f��^N���<zG��aWD�nDl\C=א�Ƌ
�5[�yS�r1-���9iҴ�ð\ܒ$�WD�m�����������>��a�1ha�#E������xyv1�_>� Y�Sr\���2�8��)�^A���,���x����$M����΍bBd�S^�}^/�&]VOhӒ�@F��ޒ>������J�K�R.��lҤo�x�	� �ÀԆ��P���m'�V�H�
#�T}*���#���(!��'���b������UcX٨<B��~z0����+5����x�O۽�l��~»��WO�#!���
�|I�dP	}���` �����tp!a�}h�z7���lv��=J����҅������n�Qgﮤ�*�)(�C����m%NהӅ�A�,h�@�̝�� ���a(�۫�$/�}Yٸ*�yz��Ŷ��ΆG|����d]>{�o@��,m6O�$u"�3!��ϊ��Tz��`J��gYqIކ�WkI|Q�ː��@���wv���I���L�H���4w�������Cߢ0;>�P����dt����G`�;����R������-G{���yNY�Z�?���O�q4Y����.���E9��Q��UO8�EQ�Vq�8��Qq��E�ٛ>�p��������{w���uz1��>i���#�!�n�G&e�2�H�7Co+q�2*�/4�CI�ljK��elq������diV���#���+>�U]Ypz�1Y��˵��#Y�I��b�ۖw]|;44���m����؃�~~�t@Z�aV�h�D�=�cI��.��Kp2M�<�'t�Mf�'�L,��&l���=R�ν2��Z��8`\�����>(@*�En1��l��iڥqy��K�43��:�<��C/ ^�!K+&����ե5Q��W��h����C�`�f���P-`��QU-��mǘ�M�N�o$��D?Z�<]m0��t�-۴W��x�����+V�)�F�U�X/6_�� �s{Ԋ��ul��T'�JEEX��U��� ����\����K��i'�!�2)4@�����]`L>7���Xd�r�]�9�m�����>�H�$�9-���J�ͼ�$bI�ek�K����E'Y���e�fY��d�븒�k���N�y\��uF�V�z!�Ҙ�O�|����o�b���/[�����n�|觰��Ɯ&�<�J=��L� ��e�dmP7�?rA�^�b��E^�>GK�&��d]D�⹺=�*��sh{A�}�-G?���5��L��)_�0�9��Ä�5�k����5=����cp\#L�hD��9rd�hjS�p�C�u{�=)�0��vl�@�U�2��h��ϥ)�f ���5)�J^����<�W�l�����Ի�4�
��s{�+�=�ȏ7l���?���Ny��H���i�t���WQy����ʟޫ��H~O���r1Jc)��B�����3W���w`�A?�8�k�TiKrO��#�;�Jh"fF�5�CO۲t��94��<҆ss��V徕��U��}j�kC����H������c�.C�$�P�Қem�.n�ei�Y\Go���pw�D��f�|iF,�����T���۞/R=���2�Y9�"[���v,S��I�
��Y=���Pt�, � z.���C��,]ȗNε�Ϻ��'$Hw�*V-M}|���Wn5	$l�\j�<A�Y��s9��}�a]�#�̷*�zW�MX^5�S� _l�KUpؓ��HWX최��.�8cT�@�`W�jf�8S�����F|�_���t-۽vʋ�k�z�o����Lx�4��3��}A#�(�d�ڶ���5��g�u��w����n�	�.Up\�P��qh-W�Dc�PK��P\$��;|s<h��o��H�EY��GL�HL\:��Ģ��Sˋ;k��������	�`"���_��s~�N���xBR,�R�&���4	8��0�x�my��qua�1���Y%6_���P�>B�J�]+If���
��[���Q;��k��Y�$�WbHL$IrU.�1���DI󤌛�'
Y����i�h,����V�=��$p
ePV���S��z3.�of�P�i�6.cgb�6E���]�_�GP��J^�� ~�_��T(�S e�,�*��hɳM2�)��u,�SS����W�1AkZ��p�B��%B�\Q�cxԺ�/֜�71/�fJ�E�W�Q��aw؍�q�	k׈*�G�G����	��b̒f]V�<Q+�!�}x��W�`�������<�~�Z��݃�b��h�y��ۇ�y�g��M��AR6�����GHL�$��j�;i�ː뢹Tw0��U��}�N����Tw�e.7��H���:�f���\�i��Y2%�ᜓ�5J�ޫ����!�а�A��[�<ۨ7o�b?7ϒJ��$N����G���Y�H��R�X�,F@53eDi9���h,���&�X.������,��!��G+����i�()�	���7�*��-����' �s�7�W�7#Ps�ڈ;{Ԯ�$��`�(	r��5ސ���sX�z�tZ��f�Kڧ�&��:�(���Ssw;����ad��n�������ɦ�~O�g,_�[*K�yZ�~����YQ��+�_��B�H¨�1P@9��G��ӫJ]�送T@�]�3K!����}w�	A]L�k�$���ž=�e\��TT�?�8 ���c�t����V$�p:A#��������J��iv�ǰ�7�zJ�^�fȕ�u���v�sp}�� �����,�p�.���Z����E<��I�	P��i����`�|�����+��&�0Uj� I�DW"���2�.��
x����h�ˎ4��y���a[��l�MT�t�ʟ�:����?Z!��
J�!�V�ak�	�*G�۾w��o�_/��y���"m�d�	��F��I��^�`�^�ҋ R�r��{�*�Ȫ"���M�k����t3�R���vq3�jE9���qt<�Y��O�@����]�m�U��Sڪ�]/�\Y��0���M���m&�QN4cT���"���ņ��q-�����OR6��H��'L����5�<͙QRȂ�Lo����<Gn����0�6�W@AC@�X�o�V4ͦ�}UTdqf}kRGoD�d9����Ӟ̗<O�� $���P�X��g�Eۯ�)�39g$I� A�Æ�q��$E���!��E��C�"�E~10�|OBWt�E^׊VG���æ����ꇋl=﷢��(��,Va�w����&����}xu�fN<�*���~����y�^�O脣��A��j�H@*� ������@�u���,�ӕ��d�"�zo��`x@܎��' 6z:��\��::jf���z�)�<�P%��v������ؔ\yύ�@�AfCٰ���-;¿�>���/)�y'��D�!Ƞ��7�c��a�6<��AOr��4��ū�^q��<���7L�Mv���;�e��� M�߰i1�*�l���Τ�?�#G�C�N�Z̄e>�2n\�=P���l�x��t�_�!�A-fs/�sN82uQ�ڱ�9�-Of��Ur��>*kͶ�'�b� Ad    @��%Z���o	�
����/�����a_A��HŲ?�?��\<5d�����)�U�t8��	 �A@WD � �,Ǒ�_��M�|%<�K�.a���J���%?V=�W�;���y/�?��~�v�s��)����<2̇
�6���8���a�h��vs���FB���m
"6��u����x����j��hҬ��p)�����)��5��D��6ZeyKY����K�LƠ�$�����l�h��ň$�!=�<��	P�$"�'i}����!,/��L��@�^Σb&lX�b�1�l���	D�2�jA����Z�7�TmB�2v��ޛz�7�Mݳ��]@Az���vM�
a��J�_[u#��R�y>�LY��	P�2)S��\����htoqÉ�6��q���B�^q�×Φ��>�d�
a��ef�x�NZ������*��t9*�l��q�t��q��̇�,�x�F�-=�ۻD�p:�LK�� c�`IDq���lD�m����p�cd�(%�'�H�r�{� *6�t�'s ��!%�ѵXA-�^.��d����M��}�Z�ٰ'�6��S�	c&�~EI��9���U��33���W��ث8�k��)��Ko_��e3�du��MN\�~�J���b4���a�i&\����7���|aO����	�V�=hd����Wl9��lZ�U\�S2���䑕dE��FC�Y���O�y-F�V#+ tD�x<^��|��~��T%}��P�ֵ�'de�	� ����|>a���#pu���Uۈ��r���$U���	EAS�H�*�ɵ�\���.�Ĉ����;��&�������$g�	<�D�E�"a6ɹ*����Q��:.U�gu�: Ws� i�,Bo���	�o)�w'��-�H�����x}���@{&���N�+퍷��-�1�����.��m��<��qt�vG��0toMI�<�<��t>��+�<��o	o�b���&U�)���*Mq	�<�^{o?qԍle-e��=�pK|P�,� 3�CZ�Ŧ���Iu����L�J�6a؎��~�~]��̫}tZ��;8����R��i�G���*��^�Y�P}>Op���0�����M����'@�;�;)æ��#_y���\/`bk��A�z	m�]��~'��"����_�\� ^�IQ[,���7�槚U��F������v�_f��i;�Gj|Yl� ���ѳd��O�	�0��Zes�G?	*����!�&�{���"��~�B���̊gcSU�uO8gE�ǖ��{5�H��'��y��@Jئ�yI
�����χ���A��C�v�_��b�5�c��h����e�Q������wv�O+"��/�2��<  �,\�/d}��-JA�r1���`_7��H��RETF��z"<�N����W���,�$�E%��4�B����ZF���^�[�	"��r>�s-�����	W�Jb	T$y}-��������Cf�r��%�r��|���l�)�q�O(ü�^�݋�39�#PJwG���7Uv/�������ŏ��ߎbR�-��qr;v~A��3�ߡs�L)�Lv0=�d�����S�4�J̘ik�|}�/�WLߑ�Z�({1�'���𲕬��3�vW����uY���c�'cS[Kq��J��L�^((�o�\��<��Yq�0�W��-���w�4���ޢ!�snd��U�R�ع����Ǹvk��I� *����:���%U���#�G�'�u�Y1�5����=��QYE����t�G�v��w���f=�-c�8r6��:��S�B�TW�Y$�2�&��)�2B��쪦���$�Y�$P,Fў/�֮0�'<�;�Zi����.�v ������!퐀Gv��2pi9K��p5	�ǵ�_�~`�Y,�6<>�Κn��a�쀓"�K�.��ё��gp43]���e2�W�-w��r���t��&H)�Ijmv�G75�@������9��W�T����ͱ'[jl{\������&�����˗��ˬ� {]�������	Ƴ@c@��h�|���uT�w��A�=�m����7T[V�?�Q���x ����s2p�4��PW�r�h��Ҫ�k^F��:6u@#��9a����=(t�C���&����wTn&D)O�Ԯw� �����a��ꖻ�t{@)����ڀ��<^�(_��@ݮ��o��N����j�����L�ڊ]+5�!���kp�l40�x�u���ۙ��#t���~A�],�?�Xg�o)������}�+Eq�J��0	B=��	�b9�|ɫϒzJl*W�06e}DS� �e����!$��̲3Il���v�g:�
��̇���v�w2xA0��Y���G8��ݫ��6C�o���D�Dz:���cx��X4�;|��#!}���A�)���t��A��u�(�p��x��4��{�8�'y�@�:ca��ؿ1cs8�cpt���:p�����o�|66ͦc�#uk�]��0��#��ߟ�A�f���<N�bM�|��zH��v�G]eE�¥��� H�LHy&��v���bB���n�ÐM���Uct�2�>sG�EM����F7�$�!d�$�4�9t�3�I��؜�zjҢ���l�ń�]9�iY�ſ�y�oJ��XC5_nob��N�&�0�Z�G��k��a8�3_C�pw8Ks�JYL熙%%
Q�Ͷ�l\s�L8-M^�v�
�Aϡ'Do�ن9��o����=�hx,�������ൟ��lX�������+�[��V�6iҷ��%�8�KZ��ǖ�/f�>�;ҼQX�7�\G�%qVN�B���P	i�c �ҏ���<V'��_���bŞ:�w[����E;�_�)��dC:a��$�j�լ�TN��;��KZ����\XF�⟫�P�{ƒp�ި"���J�
��=*� rޠU=o|La'�ގ\<�����l�/Ԡ�<�c���r����-6v<�as��5wx��;�f�r���n5:�sdA�2���<E��o]D5�Z�Sa1�	B�˯�v��A=�a�2� �+k� 72)�q?��r\1�3�U��J��Y�̶�h�u9L9�U��&�����yܼi�z���� �:35�{̌�m���Ջ=g�5�KN���M�VڔU�R!��ҫ�¯l�̀ǔxʐ��	yv���.���դ�:�m�<҆�z�������tru-����!���oڻ@!�>Զ�hi=z�HO��R�������Կ�� I��&>�3ٖX��9u���X==l�a\*�V�C�h.+�E^�(Q�
�����;�Cq�juw�;?�&ҬQiO�&�����7"���,��=�+NS��%�_=�UQc�D\��vgӊ��2y�Ď��(t`߄pռ�ɂ.�Mב���"��ml�F?pOu)�`��%�N��������?Q*����[1������t�7�t�2AO�'S�$�����H�LO���K�������	W�-G
��%�pz׽��$Ä�b#���:�|���L�����2KHQ���GU
Ԍ�[3���u ��T�(!DW�zQM��8V��r��_�"/��5<���ߧ�I���.6P�o��q�N(߳�����"��[���ov�̜(�^��[c�&�k*]*=�|���b3���s��S��;c�k؊���ʫ��~���/&�epiʆ�X��K�׮���ZN4d��ٴ�0!q��	UE����m%ry\���J��}>�L""�i~�WF�U;A��)��lUF�����W����QV��=�a����,w�5�b�w�>�"�V  �I����r$uDL���曚�7Ta,|o���G��!�|VTf�y��9�/D�,.��:���4��ކ���2��m�����͂�{{���I����[Ìjˉ���S���Κu�N �6e��WU�i0/���#n}���:�Ifx�ꆖIJh(4W��a�v�� ""Y�|9¦K����,�ڪ�:�� 4���"��*������g�8��b$`����5����0]�-�@Dx9%����>�'ȭ6�ͭi��~Hv�Z��.�[U��    �r}q7���_���܈��/���_�i�)�(�	/G]��8�W�����kW�!���ӭݟ�c`Φ�������qM�.l�F��(�Gͬ <��4iE���֞�K�&e����D�I�j}�jZͦ�zI�|�k�;��e��=�w�g�����{�a�׿#�)��4&r��{r.�G�$Z��;��ܿ�r �8!���.�-��?�KSJ83���>��d���n���́�˳��X��K��<���
T!X��k���Zz�����MP���FfE�Um�G�����w�^ʮ"�'4�5Qze}$�Ċ�09����r� �{��&���Ք��Gٵ}�.�Z��$���r�����ڴ�nf��H7^ڦ����R\��������鏎v��L�[szc�`mg�u{�'����s��G�89@�� *�#���nϸ��ő�M�I�=�2%��wd��� ��.	W�nY6t�c���g�Pd����2���xg
<�������\$'1�!R1�[��i��I��}+��1ءy�Z��D����=h��oM��$
�`�k�u��w.��6O��g��&ueTú�>xqx�_�l���Jr����OB8pr��4=8����-�z��M����}���y����P"��?w���\�ɶJ��}C�ϝձM���7�0%�\C�'�o�u�f����0��3�p]�p�������#7�rH��.'�3#����ͅ��h^e���:�z���y� j:כ��w�q�ð��ᶍK�R�����M�������v������+������B���$vn�^J1[��z���|0�v�7S�|Yd�~4q���c<�AL����2��IfdXלrw;2lU�}"��4�P����m���;_�]UU� ,�t@�$�зY�e�����A��L�����f�m4�O�|G�i�go1��c�6� 0 ԆHm�U/ĉuJ�l\m~]Ka^��P�'o�,�ϴ�8G�=iOto}�j���o��%T��Z_��*sR���j��}`��*J�|h0RET�S��3�K6@�I�#�7t���Ẻ`��5b���~k���_�b,vVg[��}S�:�:�,�6i��}^�?��FP��J�kV���Z��.<�M�����as�H2��=���E�р�����^���|��(�CRi����[���p<.p$�]��a�\3��{"�	oӤ��lr��� έ���0���*�#{$����g��T|6��u!��G�ia�����LG�3�m�!^����RNv4�%��J�A_�2[�ZCkiB���j�f��Z5�a�fM���K�8�GX0��c�474����U�3���G��X3���+0L�C q�m�h���B��"F����s3y���v��:0����&`A���4����^�vF(w�G(2��0�i�8�?v��=O��#�}�ѯ;۽�Ŷ_�~�G���3���c� ��|5��'��\�zl)�^�5r��_$b�`��ccz�8�˩8ͦ����qr�����	4U����zASė�Z���_��R3��t�! ����{�$&خL���/_�m]&mv{S�de�[P���*ػ]0!aT=۾1mns8�oڼ������.����&�]��+�id��$��1��HS/FۛM<m]���	UR��S��Hq�9!�S�4x[y���6rg˺�k#ާ������d('�2-JV"[��L�[^)ؗ��[����PtTq%�(���{����2������_$��� �uO����#�EP�x�� �-��޹�y�)�|B`kk}��N�7c�0Q�y�84IBc����զ�4>A�x�������,U��q���i�I��k̉�xR��\���7n���֝B��ń��8�1 ���ڮ�e8��� �^ʪ�}�Z�R�4."�O�0P�S�5��_��tК�K�M���q��>���0g�.�8k��[{�kE�x��k���C����m��k�`l�z�&�����2g�#�O�A\L�g>��.)���]@
���U�ݛ�n�ЛĪ��QG�FĤ\l�6�)Y��e�N�I������g�[��C6
�]��t���ɽ���QS�45�͒S��)*��	�1.!�d�*��{D�(�8�ҫOl��Ȁ�`]�ҧ��nPg	��*��{�Fy�-�� r9i� ��>�o�ׯ>�{�j�W�5Oe=�U�����ךt�{��Q���@�o;��|�+gP� ��d�|�bx��ɏ��a|q��a�?�?����z9�h�����wِ淿/iZ���&�%�Z�bv&r�3=2a�V��ƬMr���P>nw��b��� ]��N6uQ��Q~Lb�L1��Ou��1b�=���.	��Zy �1�����޽�G��V�]L�\3��mW�u=!�.��z��$�U�ic��nB΢�o�L[�C�An64�C����2���,�Z/Y["�h�>������GvU�V�Y��V4i�q2ρR�(%���),&J�a�BV4�<�y�}<!8u,E�4ɢ�1Z_�B������~�Z���$|Y��a���+��q��)�=>���n�K�m���Ʋ��7�~5����[�)���e�!�u��._U��UN�"zC�0��CR���vN&�9t���|1��|���	K�����2\�'��)�`+�P_���j\!;4q(����X,7�-��&���N�Ԗ�iRE�iƚ璧�t�oT�S2���BD��d�o���l��UA�~}�b�6Yv��bë�*�M�%�_�,v�k糆l�$���#p a�H���F%�X�N!\��t��>.���Y\ǅ��M���'�	�/����`�$�繴~���Qbs����\���M��O�)s�,��L��g���!8Q{qԱQ0I��j܏6�?<�T�tDu܊k�Y��D>X���OX��VD�����,'6�J�5���ͅ�t�}s�Q!C�9�q�������n���#8�$y�$���	RBq��Rhr��� Ӳv��rO��O��p�U���;�x!aې�J~+У�F� b����`%K�����$��
���d��/��|�I��=���
�<�$QH�̽!.|`�̩xk �3�����?�O}������Ȓ�Xl���U<Ͻφ��}����I���u�� ���R����@,�����r�A��k�f#2��PN@�eYUK(M��1��@��,�oޣX��H�{�|��Y%i
�z��+�⵩���g���>�&��<�+=�i��Q~J�(��a����a�����C_�d�x-���6=��u=�S�P[�L��YFY����#�C?j{�{�'5�G�%D�;�o﫡Xw"U�:n���dw�7`���<�?+����x�������o ��=cT�Lx�������נ[��2�lp�V��0aػ�l3�Io�fJ�a�s��v�0���,�X,���v��z�1���u�w-ɶ�nw�i�s,<�B�.?��ZG��"*�h�
 �J$U���I4t��j1'�����:)�	�[U���&"������*Hn��N�b�|1h�|1��*�},��E&lb��eR�d�%,�ڣ�b��AGJ�\+5_:곺����4�?͒�#���7�NJ&��x�^&hx���E�V	P�S� 	����ha��Z	,k�5�w�O�����v�cg"A�K]�T��$8 ت��*Cw�K�&����D[Y��׊��'O0�kf�+ � ���_�H̻_�P����;T/�J���1V�ꏜ�h2%�#��o�ѽ����@ �����`��)_
�1���z�����8o�߲���O~�u2|�ב>��cwυ.��v�|��M���	��j{�,�q��M�{sal��FZ�
�)�g��ZvA�Q[�8�$޽^mu�S�'EᣖG�u �*p�5=J����z���T([:;ۊuH\{;4w�g|V��f�[�ٕ���QV^NNh�!1�w��զ<���:�[[e�Ŵ+�    /Y�L���,)}�Jd-�@��U�Mt�]hG��R,����?��MJ�z"���W.m�!̃fL�H����H�u"¤lՋ�$��)���H�R��ۮ�;�c���%��gX�ʖ�Y��C�O�v��͌���.P����3����j���6�|�/������It[u�����0�zƗ:���S^���R���߆�է�����T�=���)�v��Yu�Ɖ֐�pJ�\��C�R9hn㞦?B=�Җ~ xى�����x�^�~	�ׄ�鴁�S�u�2��/lzE����z� ���~� �Rfk�H��r*+��]��_Oh�\?R6vrצi�HW���>�<��Ŵg˚������'�7l,$H���ǿ����*/��긫&��e�7�~����$"�ؕ�U`n ��j�;v;�Ã$���\����Qp=&$�*IS�My�m
ώ��u ��W���̟�3�]^!�/�Ithݽ�'��Il���QF�ʂZx8%��+�\�H�:�$&��ۻ;V���������6�R��U��ʢ�P%3q���-m���t���ĲqA���D�g�]���'��MY=#ǂk����(A���e�Dܿ�
�q���b�h1���x��P�������z���$dґ�4
���Gk)�v�U<�>Z��gV�3%��y�t�����H�T���QP�}j�E��v��\�U�R�j?<]��e�"d �ݳ�ު�jg|2/�L�I�~};<�p5ic��� {�`��v�Ӭ��/�ɗ���+�f��i&d�"�bC+�u���Y@&ܡ=?�5����'�G��I54�<��6�H���1��&�1`����@�����̇	�C�[GX����7�������y�t��7B[���Ҧ��	CˢH�X/@T����c0e�+�CX��,;{�(	�!X�bS��<�6��L8�eZV����{�7KN
��z�q�S�C{(?����:����|{ ��� D�j���T���>�/Ӥ��Z{��yh��Ó�ײ{�_�.�K������fg��ͣ(?X�M=I���Ӫ�p�:�t��������YDB)�*[�>��;����G P!JG�p���HJ.�l�����u������*.�v�Q��ף���L����� �#�7<KW�ty�[��/�dS�Y>�Wy��m�F/���H/�!����Q�w�}��-dRM�R�M��,��/��i�~����:S�Rd��?�f>)&jX'6b�'�=��a�� �6�)55��a ��H�����$>���0�i��vfEy(��Lw _�t��r�p�ZC��De�[ŕ�ր�v`z�+���3m�c��m7MRy|�������{6Ҭ�?�&�gƥ̢��D�9��?������!�tsa��Aj|O�2f���������9̃��¿�[�e���*�j���ł)�y�(�^!~�"6R��� f�����"#���'��o �(����SÍ8G��P/��MT��������'�"z�w�����x�÷\,�P�Q�eF-#x2AxTr8a��ِ��$�A_m7$\H *W��� �ev�(�֔�D!��(��6C/�OXTz]D�R��z0�:S����[�cR�x�a���R+J��;��5�26�+=
X#�t�"�J������
:��P/���LaR�VM���|@��9�]���ճԜ"��<r��A��ٔ���2��e�QR�� �* �:�b8|�\������֙f�����K54��N�-���P����Y��t�n6����n�ʴ�k��HH0���X�Ȍ<L�\lY��[$�������j���m�Q��'x@ǁ�`d8���|�m���� @���ب^�!�T�����i��U�����Oײ8O�v�A˫��ؤh�)�΃ebI�jڃ�Y����5�t�
�|�]�<�����F�$������m��z�3;��<�����-��18~G?�6����g������[�$���N���	"c����ʋ4�\N<�T%�!q��,�:V�T&�KX�ix�D�rN�2����4]��c�>_�Yl1W]���:Ko_�a*�Z������J?T%A�5�� 2�V�;Bm��2]]�V�̢oE,t�P��㖊�qOp�/��@!|"a�:��4A�i�w��뾙P�5��I�ydNC�\7��J�Q���>rf�&a��1��@�EU�~���IM�,"��w�C\�޶�7%�\�~x�)r���^P���P�O`�^UδA�ѐ;Il�� �����i'������P&�o�92r�en>=�'�7�]-&7;|�@�8K�ܔ<�34H�}bc�w �=0�W��L�:��b��J�m���Y��(�����yV.��&f�+�F��8��Z��mL������}��Qs����p/�|������$e~���z�j)Q�&�L���������33��$L�_��~��0�.n�$���F�[=�&��%q�u�'>�^��sYE?�vd>�޼�L�ѹ��T*[i8+�K�1�A�#��j��.ֻ�ƈΒ4]7���Uǩٲ�>~���p��I��8�Ѹ�~��Y���	"�U��*��G���q����:1�\��Y}��'Dh��i6��,)���pኦ��GG��1�W���zGH^��r|�ݤ����� UY7�����6�8��6�����R�ν�T���'�Q31^L�a.�G�TC?A�����V�]�����֒�34�Z�=�ӽ� a|�V8��N 	k��������c��P�b��)�d�O��۷U]d�Ū��V�����&��Z�{	q�y���r����Y�6Y;�6E\�Ҫr��\�A�Z'��,k@WcY� ��+�]9�'�[{�}�	�_�	h�!ig	`��]U�U�aoUD]�Ɇ�P��]ızm_�F0&�7������z��0 ��_��|��M<a�Q'ye���DΓf
�+-�~������?�k޳]68nZ�V���%ٸ�{{[�z���d����G�{#�������:�8�Ĺ���:oL�%)0^��B�[�/�(��y���?LP<��-��A�la���KP�����$�	��c��3Xg���U��W���ۓ�ޒ�ԙ���{ܷn��"����~�I{5 0�7����4K<��#!�F����
��j;ꟻ��� �5q�l�e���q����k�,/���iu�!���w��@^U\�H
�|+#�>@9VN��z���j��\��,M�n��-�*�ƽ���`�t6�o�寷,,E�׏3��ձ������\����+�7�T-g�>��K�f��o]�����,��
zj�c�J�d��d���giQ�4��(���� Δߺ��� h&�̒��'���}wדݗ����{wA�'����r����i94���V��I#�)�ϣ Y�7���,�g��g��e���d�6-s�����u�آ�΢�	��3���b�<���{��_7 >����b�f��LP����1�:����޽wT�4�l;�����P����ʾ`�a��v�=���^~������=�5q��D�.�b�3l�Kp��f=���v�`%vC�mG����K�/��8��-��2��R6IR�v)Kx��hX�î�|�2@�'���#0�r
os!�Ҿ��Oo\20�Ӻ�~xj�Դ]�� �P.6��mҘn�=+5Y�$�:�:����S��Rt��bvҠQ��%��!�|��~$i�"�l��������`�Yw�C���	KM�����nw�=�
�Ӛ�(�ŏ���={�A�_\}��-�^R�^�v,˫Y2X���0�qn�c�*b�P�����D���|"��e}Ա��!����iDl1�:I�r�×u�������7Id<������i�~�y� ��B��Q�'�,�?+�r}{e�Tqb��&��������KnJ�߀m=�T��Ӟ����F�
8�[��������o�	��vM���/��Ӄ����o*ڹ����DC�<�ݰ�d�M�����J�q�]+w@��    ������*�P�7�B	|�N��W�z�)�g^g�{���T��ö��#�`{a�M�
��~��L��g��iȹ��t�^�@�kՃ*LYL$B�z��!�%��3)�$ �],t��f����c���>��5��� hz�7��{\y�m��xɏ,s}V<�1p���ś<��"�<z�d�2O�0��(cF�p=H���G�>�\s�{��#!��A�^��e�!d܀�L�r�GDޱY83��l����yTg���a2Hr_��� 1���QP31���}�����������`���q��jH��(u�����x�����'�:[4�j�D�������������chp)|���G}3G��b�#�����x���^��o���'���d5�k�)�׻���dK����E�!L�1�EZ��	/^� ��U|���*�s#�4e�w�X� �?��=�覼�>!"�r��s!����|BD���TчQWT�<�������\��00�l����f%�X����ls�l��lB�@u�p��)A;�� ��=�\y���[)?xa��{�]�����^q��T/��m�!��&1Hy�D�����6�"�Xx@p]��#i/�����=Xo��aJ�	lvp�|��Z
���2�I����#�W)OiǦ�xTч�ydN�~���յF���ʉ��:j�6���ˇyZ$C{{؊"ѐ�]�����HxA/v����;ڷ=K��Cΰ�~������N°ǆ�����f�
�R#����N)7���-� ���;�����!��ß ����}����5�k�xZ���i�.0�'h��ô%L�У�U�n�k��Da��e�k�Su�,59n���Q�#|'����	�|鷮��<бbo֔t.d�Uݻ^؆��}x�֏�֤�;u�%Y����������8�������J�A�>͂@��i[�9����8�����s��,z�򭥊��b�t&�א�U�O�'��Z�xNN��]�<3ך,/����(Wu�
X�w�F"݁pdYKR�Ezw8�ɔ1�L����	��^~�C<jB.����\VQ��/<6DR_9�R��V���C!itM����i�}���Õ��Z���bۦ��by]%����)��no��U2��(ԠL�	ϱyCY��n6T@޴��!�����*z+G({�xO�;�lm�(ۈ����y9`h�⺜��le\����OO�Ym�o����&B�\�-U�<�^~Z�F�r!_��6ɻ��o��IW���&�� []�l���y�����"R/f@<�+m'D�I���%q���(�y�%���e�l�@�Z��a���f�_H�|r�dҼ�q0�v������:<�h�v���� ´H]������|1D�:���b����h�MeD)������QȾ�+��P�p�E9�����O<X��D�3�{64�7e��^� �"�,��F���M3�,$'�Ś@����K�X��!�E�/N�bP���G��)'L���j�D'/��)[��|��쨇��EqF��I��y�#���E���I]E\$��UX�WI�(\�����R5[�W���;z�h��Zu�҂�&�̒(��.�$>�pI_���L��IQ�o������<J���ac:I�L��O�.�F`w�����6�@Ͻ�s�������M�b���Ǉ`�pxa�;�Z��L	)ѸQX��tړ��jF%<�>I�6?�ЗDJ?t-����j�q���(��%��E~ ,Ҿ�RѶMW՚�g>t����>�3G�	�5O��\/9�l�Y]��LHve��%���1�/w
�\�r�Ȗ��K��ȓt��1��̚� ���U��:_���� >is�`�J"ǵfd�:OA��E�=�,�v��8�0�m���U��m;fR9Ap[j��	q����lJ��j/aMB�����n�z�9X�u�*�]�ٵe@7*Ճ����rȣ��Z���uy3�IA-�o�����*e�\n���t0�,��L�g�����'<��%eD-�����i����'�W*$w���ٸEY��tB���f�I�V�=2��xå '_��W{����$l�	���-u�T��J��*��H�O���mgEUՄ)H�5��+u�N��m�t�4���_����M�j,*� ���e��)��2��������s�b���&zc�qi��"?�<��i���v���O�7f{$���ԕb�����f�����y��Ʈ������l-�Me���:㡥H�#&��L]�o�Xx�f�V�~��p6�%����ir{�&e��f�DԮ>w\�j&t$�=�	p�'�S{UV�=]+�>���i���X���OL��Ժ�4�r 2rm�� �)]�����f=��dY��6͢Ϧ8�jIc�*�X���;
�W�l���(�a���7s�C(8��R*����.�/��R]�O8dyR�v/���[j���Gs=��d���P�	�N�X?r�C5-dN�4�"|���������+ L�0�Z40����>Sk�WO��2�x:,�(�@!}i�����/�Ҫ��W�y�zA�%��$WV��?�d �Gv2�y�n����t(_����v<��ʺݕ6!��Z2�qn��΃����ǠC�n�\�!2lS���7�1���3[B∿�$\��f��u�Vn��HY�7������N$��~��Ƽ�5���0�&�г|��?a����8��+�Ë�<��$��	��^�Ȥe���s�����xft�����ꐚ�����}�uó��2M�nB�`ӣQMZE�j��a.+^=ɀ$ڝ��٬+��	�t!_�v�	B����v0N�b��u�ϴ&��%{E�0�"��OՇD�V�D+o�b�	ü��ո����×+3'ͱ�o��v.G=���i�$�]��@�#������`�r��j1 �|.�4����uf{�,�> ������8	E��\�ih=e#��ק��X�|=��:��(%���	MU0%K�wf�M���yȝ1�Z�����˓~@(�-])�D�&>����lk����	X�,ƞ@1K#��Ĕf#X5���� X9�Z��@NW��V�"��o��De>n��p;�'K�ܶ#Y�މcA�̎q�v�%�[K��v������a�b�-�~3oO!���j��vDL���pc-�fD"�b���&ݽaw������Rż��u~$��gڑ�]�f7y��a{��,�6�d�z�:K[���Z�=h�RX}�y�y"-W��vj*���ڢ������(�1lIhɬʆ���ڽC۽z��;������'��4�u��я��e
Wr�ƾ�v�����`�:d��w�*��8�&,�<_�~�ᬒ
!^L�g>�����	ﶫI�_��G��o]��A�Vk.:Xx�G���;tM�\�ye����������tU��ܖ}٦��V���;�+kG�?X��z��l�c�-#$�����ɚ��ڷ�$�QH��w�Xn�)\?����6�1<��us����MUL��"v�����a6��` �,w��#N���$<~���3�9|1�jk[�Ol{\w�������>���$���Tq�n�����:�eM���uO�f�Jr�d[�	��U�f;��v�G����]�tB��S$��,�#)���x����D7s�Stk9`�-י�&pZeM<��UuRk��'�<n�V����f?�����}����zs�3��H���6(�2B�!�
�b��lH�H�rB=R�I�L��ч���>��W���1�ݑ"��!?B�7�j{�6�uT5��%�DFh��O�� ��r���߱U������nqSƙ֝y}��7���C@h��><����(oG��J> �N�;�ڹ�k���%{��/_�%�z�	���-�y�S{�އ�	{K��a�+鳛<pa��5%��/�b3�^���c�<Iry�dyA�),*��ݵ�)����������/GޛmCR5�f�NM��*^�2�D��=aȏ� ���8A[�G
1    Zn�4[�U��r�@C�V�q��J�'�x�0���%<"#����z�^L�h6VL徣	��<+r����W�����aJG&�v r�*�\�y��V��n�eqR-V��F���� ��Y�X��z���[�Yl�޳r;�ƘA��&�A ��+`?����Q�f��ٖ��E|��p�r��K����(@/>�!�T1���mk�m�κ��;@�U�r$w�ٞ� [�
@��fA��U{���K��O_ �p(M����m��/��#YW�<��͸_��ѩ�]�M���j6q�EsPl�8�����sj�1>��J����"뼚�2S����jq�1E6D�5�E�&�F$<������$\��@�ؚŖ��C
��r�d�>Υ";1���*�ph3�[e�e‘ʁ��g�eCh����8Qe�)sڃ^ۼ~�,u*!l�U���u�P%��'��r���X��L��G��mn�I1I�Aɱ�K����ys�s�<��Wo�F��������=�w��W�����B%�����)�ͥ�\$];aS�i)Ra�~Ɏh���W�O����N�[/�u�G�e}�Aua�pe=-�L<5c�O;���a�Y�)�&�=t��Dtm+<ob��o�TdE�^o�c��flO�vl�*�yܴ�|B�P�%W� $MU%!�����0��A�A��v2vܪy����y��"o�|BXm�*K&��6/��+��6?_��hw���G��2<���;�������^�myQ�rB/h�T"�)9Xl�!3�������<�<� ޸�_�U�%�<�A�����w2�f����l��Ee�eB4��p���*)��JGG�O�w�^8ɓ���upb��A�SN��4��h9�B{uE�CP+^�P�< Y���^)��;�[���[J�p���I�H�؃8���r���l��mʬ��ҭ�2�\qMï��ϫ ����6��i,�I�t�4�C�.�=:&w�:Y|'�R�:��0[���̵���meW񄳒�xȻ�A|�j���n^�i�]�8���N\�GH���_*��',�#g3n�f,�����Q;IJ-P�~�pC�+[VW��{�(��GoZ9�d�/�D��
�Jmy���o��Xo|�h��q<�{i��2�Pp�V��גj��w{��#h�p��Z#q���1�p6�LvO@�*w@��D�:oqc-�dF�Ǻ�
��~ͲY�.���NY��g���*�,�no{M�&�<���)IIH��>^v��E*Bu�^Bu���X.35���:�p͋(�5њ�`@vR�j:"�C���Ӗ6�؋ ��7����h�&�YNxx�0ի
�u����YL�s6]�����P�y*��I�c�o����T��B�ɂ��G���� #Nf�S8[\�E��>H1eRDzW��kw�O�IM:���(�SR/ń�c$��G���H�*¾!.��d�z���0�=hY&2�Ί�w(�(b���:ȧ;�d��m�H%��D˕�*��)�
��h�K�L�k�7�kVL��f���de�+>��n����`|�NH·���p%�g���L�\O�8��x�;Y{������x*�M���m�|
���%}{��PT�pg8��ܩ���Š9��쾇�P�����[aw�����^A��)��qM� �Ķ�~�2��y�3l�U$�-�}|�$9S���鴣�p�s�]jK�)ϴ�r�Eݳ:5�\d0���L8+F�y�%��rJ�s- �<k&��fQ�e���a�̐��X�.�l���w���D&�\��4�,긙�ؾ�r�s`�\qJ'��ʸjlg�{e}��V HN���Q�����E�Eճ�+j���˩^�&�[Vi8a%�%Qn$��1�/T/E%����aBx��o����~ݞ��cN�X$�� QP���rM�\���.�	SYR�F�r|d�My5u����=�W�$d���y�Ub�uKe"��ޣ�I�|��=�զI'c3[���%������Y�.�#vX��c@^��<�w�Sn��	�o����C6��K#G Al��d#6���J��ׯSV�&� �ɲ4S��<>�v�bH�������j�X��td�ywS�ٷ��ql�� �i��#��,'�?��
�!�=�9$�%�9��nr��5M'X����I����K�
�뺿h���F���!��Y��M7�{�} �	�Z�E�f|D��z���|&���� �w.Ûǯ�цs�£=��˗s��I��3��"K�G���g�X/�/�'�0��[�����H�,;tή�"�K�n�,V��6朗��&\�2	#Ya�F;_1!&\A&Z�k��1bA�NO0!��Dx�r���x�>�TU���U-	�^M�`��|���"�R�# ��=��a�*�t݌P���W�q��֞����V�v?�"
�G�.Ե#)�Ăe�"U�c�;ǘ�t�Q�[8NR�U����� 	^���~��0�s T�2�S�����c	11p�*��p�Se�M��J�|s8+�Ru��(x����S;e�ɂ����4l?��
l|���꽓!��g�v��`D5���o�p�Z+�W
U&��*��[��0��P��{/�Q�'q�^��`�.w���H8 ���j��t����|�2�Bs{��Ga�L�Oe��Ǻ�T�PʳJ&�ީW�hc{�1�@Ԯ. D��U������r��ޞ�yJI�ou8!�nt[��[����N�D�?]����p�8��������"�&L�����
����1�U�֞���ƿ2φ"��x ���f�V:BP���3c�.ƫ�M�*ð���Ź�?�a|q[}���*���W�w�Yj�2�*�l�F*O�8�����{��
�=�~�%p%\�H("�-���a����)���K"S�S�W����ŊW�0��#���v����ub�/����V��Mx��4Vy���]�\��yբ@$�;��ly��NG+(�E�5a����΅۪��ل蕦��a�P̪�:�mO���m��T���/������_���Ev;�77��QF������E{��'"͕�4�U�_�i���t�{X{��ew���G�757�S8�vf�8�W�����miR��5����ug��q���F��zDy�r1E�ǜ}��ń��$ t�)�;�>�Шk?�<�����g6g� �y�DZ���٢U������o^���Iws�G�X�|XS
�\n]3�v6ɔ�;/r%��&x�i�Z���;�(���U����A�d6��n1����:*�	^y��9�,_f���PN MnN[#��Q�~�G������l��C�g�$"�f���\+�:��rB�0K��ȃ�X�pN�u�q}zt��@���8no0��)6ͣ�qP��A����@4�N�rJ/^f�:q�E�/O���{&pw��.�X���\��<x!f�-d�Ӵ�Ӥno�YF��Q����)�&s��;Wkۄe]_.��%u3��o�8l&�"+d�����"�"g؃! �	)`�%0���p7��#�n�4SU�/fY�,�d���?ѥ���
��Ԧ�'(Q�ʵL���uג�ș4La���v�	�)ƹa��r�����묍�pB�
���@��ye-ἵE,�Sh�J'g���щ��_�K|�Ϋl�2f'�̗�$�;'�?2��i���3���kt�[�&u+���t��*>�������"��	-.c���0>���p�D���g�S�����X���t���k9���*~����.>��.�|�ƺ�Mr�<�H�$�8�`������?*��r�T�����c��W: ���]=V#²��!�˩��&}[WM[�^
i�
R.!CM���4B���d�vU��m�p���Q>��6 s͉R|i7w��]\��ާY��IY���I� �u���dC�
�
���W�!6
��94>���/�뼷Mh�	�I�PS�m�dFɨ�R��W�C���K�����q�GLJ��C5Ȭ�j��58�^���:c����n�Ch[�R��"x+    ߹ UG\wݸ�ܰ�Q�H��?�q������ⴟp�,1Z��9T�v,���!ә�%zȞ���/uG��b�k:�hY݇��g�ǩ��!
�pm ����fv�z��'d�p0�iѬ��>�0�C����S܄q6A���˲�$jQ�2PGm���w�W)^m��;D��s���������3Y�Q|��)�KT��(�@[gaF� ��R%��U����^��E�ϧ$��y9|h����1"��T�8);����[�����QU�׽����MHOCN9*M}��q,�w-'�bcT]���C~D��,�
��I�{�}^�c޶�n�3�&w�>���5�`gT�j��'~%τ6Ț��8Ƌռ��h�8M&�z�2I4qFI0��Y���@�#FPңF��������	��>b�%�F)��������2�0Ǒ1��|���X�����ʢ����C��^n���	w\��O6��?������̿vW�>�;�n��W7��Kk^�ق�]Cw(�D.��j�&F��^���RT:�?��K�f{�*_F���'�R&�p.U�J�} NV-��^bk�#Aj�S0�-�g����W��2��w����.���I�bBOQ��(t������F��]�O7a���ǔ�yj|(K1Z�hj6��&mMq������He6��ʡN�g����Ⴛjo�M�@i�M���� �̫��)�*�D ���/�7mL�L9mQ�g�<x��4=o$��h�P��KeP�@� �E{��.:�:uΛp0J������N̄C�i��r`	H젗}�F�A�!l"A��j���b1��lD�&/�	(�2��XO\�d��)H=0��x�IsEX��d���Q�"K�	a��I$<�8�Q�����u-o�`9Ň��|M�de3!E�S�ʇT,A�Z	n��4V�쥚)"��L�����zK3�m��xQ;���N�3�j��o/|�4����8��F��zr��G>ڛw��������A�����'Ĥ,u�'��PONl'Du�۪�z�=�B�	4�ǐ���֝�{��.�>��#�\(y�c����-�����7Ţ ��(**��-B����َ�N��B�M|�֠~<�S�4SQ��k�"�C~� �RP�V�xL��L����b����y~���Ϳ�$�n�E��@H9᪆����?tW�,�Ґ`L 5/����8�8��&��o�PK��5�V�b$�A��_���/3 �x�1�l���n���JcJ�S�q8E���|ŷN C�Y������b`S�>��"��lC�Љ�&��1Yl�7�gH�4q2���H�y�	ē{�n�͠M|� 1��6�)��oK�� =�F��vХ �=�^��9J��V�\{�0��iv�<����g�B��Udc.�L�]�V����Q#�A9�k>��p��F��5O�]��W|uh�ѯ1�Ћ'-���@��E�ﯽ�Q_m�~M���X��yX�0Ck�L�RM�Z��8֫�*�#JG4��\N�r�_[��6mJ�,�r9r?��Z�]������8EJU���i���h����=�yͦ#�tY;�nZ扚��q��N=Қ�����7���]w���,���U�����J6�q�7(�l��R��y��x����xad��d]���u`�Il�ߞ�+`w�7邻���'t�Yºmn�����"jW�Dz���g�Yu`l�6)��>�}��<��){�?({l?����j��(�<ye��6!I�*�{�T���u��N������a�̓Ai�$��5۫I��D�/�"ç���R�������r��l(�6��(������4�ͯ�pEVV�h�d=s*L��;mO��ɍ-v^��b6��/ۤKo��!bEQjĒ��}��\�b�q��.��#lF�r���^���<�M�V�G'J]�����v����Ρ���|�D��K��������5��̣lB�ʲ�0��� Xn��3���c�98%(��5T�w�)0\E ���^v��˱��h���V�bb��m�UEq{@c���I�jH�P���	z���2
���g�,v�M��͓.�o���v���W��H�M�l����t,K��F���=X�ۣ� �!��-g|�(�'��I�h!���^�;���П���࣠o��7d����3��%\�n��}Zb���@8�G����U������\u��f8w�����i�2?T�x�:�A���j�?ȯ b:���Xo��u�r�W��2�Y�b�\
���P��� 4p���?�:�0�T[+�0S�c��c+Z������#��[;�l�����]���D�#�H(L�1Ӗ�=��!0*��'L;�ˁ��ث,���dĄ��"�F��N�b'u6
u[��Lh�HD��4~aa��c���:~�+,��v/�#u@��S�Ŵlg�J�uٚ	�L9d��F�'12D�R�D��f�	�{D'sn����� 3;m�.���͠�I+(���3�&���Ml�ň+���:=q�������Ha�r:I�Dg�^��raĎ�����RP}>����%չ�!���ް�f��ߺ�m�N��nGz�H���J�ˬ!�fgxyتC%��Lx݃��}.ko�A9
iRw��s�O�%�-VZ{ds/5!���8�ÝX��M��mz�M�t�R�xoD_B�o�芄%IG�����ޏ��^
Ab�僐�(�-F��/�w��n>'Ȗ<Mw�sa��؞� �Pp�8��{�e��/�2���]N��I�xh؊ ����k�2�
;���y_�7�,RXnR�K�aͯ�(Sb��o�w�{8�Ag�[�݊H4�h8޶���e�1vՂQŋ��wԃ��Պ�b#�PBO�����捷_�h+�S ƴB&���RD��ŀ*{Ӷ"^�7�rU�|�G��6�!�k2�}�a��C�p8Ë)jVY=���-��.ʼ�3��|�w��E �4&>ʌŌ+��hl����}�$<V8���*�$ 
J�����,6H�M���ꤻ����Q�S�?v u��⌫��UI����Yy�d�a�lB�]����5�}�3�;�Y�mNw~�WM� *�=�Í�bb������I�.���:U�#������>��F?����k�ۧQ%��?�<���$>Gm8U��.o��=[���D�"�K�H��N�h�>.E�O���LW�I6Td|��U^�a!w�2�n��2�`Ʀ�Sў���O������~�"ǭ��_��ZۿMK>��@�2鎎�(���
�iP���P���\�[G~��W��5�4wރ������P�����Nx�����+�w-0N��H6�$��bgk/��\=I�)5&F�r�M�����]�񄠥�'5h0&|�S��E؟�9����Q=�Obb,��_�<�+�pº 2q�݋	��x����אTMY�/'�^q�p�ᭌ#]h�g�>b��6	� [K����i�N8nY\��&
��Xْ���;�u�1�\D��i�d��ɓ������/���������¾��"�n|j{\*p9e��M��q����M�,�]J�y�|11���]�Մ�aYHOa���c�FJ���g�Q��{a!�/�.��F�>�Ј<SL�	 ��;e-��=/�Ϙ������'�(U�������GV)X�.?x]8� �N^/�H��{�n���6<y&Y.g�%�ۇMM�:챔kL��xyPEYg�De�m��$��cG��{�U�M'�o�R�{��~��ICEζ��m�v�k �E��H�o4�X�h��_D�
F�R��7Y�p��t�d#h�3A�˴�����v�����]���g�,<;¯�<j�۬;ڴ�Xl����bFw�)d��ۍ&�8ʴ�0E��D˼��*��e��O�v��.6����ԛ��0>���ɔ�vG}l����Eʘ�A���WQN �em~$��-���9c��: ��.�I[mwH	pW\��Ȫ��    �_�F�Z�c�MP?��'�@#F��l��YBꑭ��ٺ��	�5Y�T�+�^��q��1�R��.���g�>9o��s[��D.���f�N1�@m9�vj��X��TA6��ˈtz-D ��|��j$�����1Z�[��)(��Ϗ��r��@f�Ϣd�&
�Ue�dapO4���g���:]�psq�KH��� *C@1�ډ� �+N���볮��4�?��[�Ez����<.KD�ʾ������zh���&�J>L���3j�b�׳M6����A��Y|���s`#��'GV0�B��Z��=X�Ul�C�&�ɉb1_中�y�r�u���j�T�3�$�7c*������z��q�L�1y���FĨ�yy�R0���
����æ�}sgY��]|<RT�;e�fW��C�~�I�ΟM��o���}z`K��4�'ѵ�D���%���(�T�N;	�!�s���l��-����N\Ħԋ�ߎ�}{Жj}�C��@�5�=���.�J�B�x~ x�NО\�6�_7N���b����}�t�q)6+i����u�';�"����ꌶ��g���T
����^� %�,NoϠI�gb�fbԪ-�ϔ��.��T��g�Pu�'�"W�S�b���j3��i�Mx�[�DY�Z�y|�I6��3o��6E:#�|��U+0�kW=�s)���li6�4L�)�$6�2��(�\]�w���9&�#()ȡ����p�m�\�j�NP����Sy�I1P���;�/���9��A�!�zz!��P-�e9�C"wO8?�W��!'"O���x�Ξ(��_2�
��M�'�a��`�zm�ou\L��3���� ��b/Y��<"*:�EZ6���$��X:z>�06�w߉ɕ摛��f�����G�yi}@� ��������dVI��>�M2�h��g�;b����}��� �ٗ���#���=%z����Q'F[w�+6R$�[#�f5��u�4\��7.D?wt�nC�']M�z�b��i,V�ϵ,MæJ���|RD�����U;�z�`����ޢY��C'���B��i���.�ѻ+��/6����m[�NWQ�����+'��-PE�����ޒO:p������=/[��w�zح��2���:-�����h^<�:�~����[��	�S���N���ń�;_Q������A*~����gw���B�{���gü��k&��4�L=a�e_a�T����̑f�߁t s��.l���/ A~�K4))�Z�n�����M9kEX���Js���ӯfBX�ԝ�$��`;��&�j/cN�[t̓�N��P�pGY����[N .C%UW�^ǥq^$��4�r�c��cr��Nu���}+�gc#mI��MtR7A��������DR���b��\�id�~B'�&E�K�R����a�Jb��+���@BsRf����>9!|eL��'�t�J��Zq8��_A�[~>%4�S[�T���̉�m��ب���B
�;��w�N�t��ھ9ݏ�S�#�Ġ�>~�����:� ;P�h���������b��M ��f��?<�^�B�����o�o�����ge]<��ڶX��E���,@	�jve�R��A�����o��Ar������c"p+m�%h�� ܍z}v���YlN2_�.�p��Hj�P�k{0�'(H��7�b��a�$��A	�C_�g1A���@�	�4KF�(���1݊�2��oy^r�5]�����l�#d�]�mz{>?�T(�R7$��60��?���@A�O����6���୊��ʃ(� ��ȿ�9������s��c�vLkQz�}�ԏ�Ń�y�b�p��W�?vo�cߣ���l���D����*���<6�7@q�JU4�D���re�+�L�q�ń��+�Qד�a�Ɦ(�O4��t�"��*!�˫[\�����"�V�D��H�&�'�y,mQL%-��D%���w�,ml��Q�Qye�!�~���͉���Κ��n�1S���]�GɕG����Fux���s|sr�T[��jER*ȫ����^����GH-��ϫw�G�z�6�cbmE.6�ga��&�����e�J��k��0y�z��	�]i�����eH��"5A#�'[��mt��#T���b���+�v��R�f��TZ��Z]��_�q��=����Pב,�Q���o��a������P0�ct��/��ͥU�FM�O���b,S��2���suH�ة��dLt�w��۝B�:�*�st���Fm^O@b��-Jd;_&�q/� �"���Ug�n8&��ǎj�����.5��}�L�Nȧe��2�*��-.P`Զ%Ud>J5�nW���u�I^��z�qmn��?��du�tb*#j���{e;%�l	<׶՘2�1۳9(��ܮ�B?�0�}TLS��z�2;E�F��<�O��R.qYN�a��=����-2��%�x)��I��~CޟsF8CD�G�ΠR@��ut�Ո*���5�� ���KY=����fKEw>�Zl��	#��jb�E ��g�=Q���vEq`~lUB̖_�C`�X��4Mo���gc�v�K�Y�ؽS��Q��D|�係&Ү��#�>*��P�\t�%M�E;
��3,�mc!7��8���H�ݏ�����ZW���sn(�HH��,�W|B���5�O��_GW��v����Z��{�f���q�6�\lRա/��mG�����ki" s¢^��CR�^��o3A@:�Ek����]M����aNQwө���!�S�&n��x&j��~B&���I2�p_u��眬�vV�L*s�F�
Q��V �m
Yq�Nw0{~�d�~��B��>C����V�t#��*��L��H?�s�Х�B�6`t����4�%�`-����I]n�=�<��2�'�T)����W��=y���@���N(�u�?��B7��0D���ٱ-|-���(�����Y�4��	5N����2a�Q,~�#s���I����孪��Js����Yβc��lҴ�P<��.������U���&�?�8��g)��Lj�b��u��5��0�p��<�K�YbOk�cS_C��9_^)M�&=�{��dM�����4PM�%]Vt"s�f1�l��8�	�cl#*��uK�)IɔnA��
N$f:��Z�Y���;;^��_C��B��[�lX5�}�����$��~|��Ef��yStS"[d_7�	~�1�O�`�u�y����V�xX)�Of1���Ӹ��hBij$HY�W��v� �~��d�t�wj%(Kv3�3�5�(�e^�zU�eQM8Ty��z��p������ή��*�D �:ϴ^N{i&Y�4����P��Y�i��=�,jH�׊G
���jה	a���H HXB"֋��\]��X�
HW�բ�����48!	b9-����&�'�9��Tq����sc�aK��ͻ?k��� ;�A�Dyو:�Wh|8-R���'��l˕��#��#�����c����ͥ� 6�G��_)ύ�Ŝs����0��j�uO3P����E��m'�M2�����vh	
A����mK���rGK�9!��w�B�vEN��:��?��
�G'�J����:���j�M�Vע���σW�U�C.~�Sn��b���pwqk�)���~wr���myd2���~kGQ/�z��C�?v�pب�lW!�$LUd�J��f��\���K���72�\ܓL?C�v!�^���Vo�~u���ĳ��ű o-��o�@ ��0>��N��K�	��,�L*�[��!�YEW�m�`�3|����{�ϑ��8��Xo"���{E;A�-�y���:/GU��5��ת}�"U�X؊����ȩREy�gE��=; 9	�F�%ny
?$��(	�ǜ�z�	��k&چ�"�y���xG� K�nh�u��_t�\Gg9�y_���;T$�v��0�9���L�-���P{R� {E�[��6���xM(��X�
&J�    ��*����"�R?nnVxD����*2�M#�*��/�f�%����.��R^dz�M����E�����E�?��r��\8�E����U'F��L���$���>,ʰV�`w�6�j��6��ā�싘h���lBI\�*Y\��-ޡ�{��b���i�����u��-&L:��A�$yN�n��u�����v�����g��㑯�#[Dw��7ߚ'I�~n=��/���R�F��
� J��L���Eh�3K�qT>�-��2�4.1�Mp������(�p�M��G�!{h���C��3-|mY�$�ĭx����V�zm�4��|�3����MLa�t��ݾ}�[��*6�z���W-'ۡ����	^��s-X�|֒�h�Ƀ٪��^��3)����'d���G?�e5�n�^����?Ps�}|���y=u�����b2 syڥIY�Ʉ��g
t5q|�	���m��3w�՘�/}��i�Az/��5WO�TM�M(+�$)d�����[�Q���.z@h��]�`]iC�1_,)̦-��M^MH
EY�([�� ��Y(aq0�D�)�R�7�X(~�:�S��Q�H�������'��I��.T���o�����%4Ӷ�7:�`�������G����uIl�pgӜHZ��ޞlU\�4��
���X��@_�7r ۜ9*��H�e�eR�t��Wk?����Z1!dY�j>(�_�(Q�\#ҟ}�ǒ��4���Qx�+���b3��޶U�\d�1��e �n@�ǲ�Mŧ�Ӿ� ��@���5���ye�[G!ҤZ�D��@�PH)�@Ɠ4,�q���⛗�fZ�4�z��B���rő�����~�@�}���yV��J ������E�f�,���8�Ӫ�ȩ�TȽj�*�Ȳ�ξ���e���pm��o���[��L8��٠�N���>�/VTp~a�d��CX���Cvń�v��Ғ0��ߟ�ip�-u�����"bIݯ�9����\yp���;l���f�����"��/��gK*i��y�
UL" �m�E)��r�?}qJ���L�I��������0M�n��]�i$�$��w�:�)��%,y�Ջ]C���)]}r*x�L9@��K�pGn�\�,�%?)��_U�^Q��C=yI��Ӎ ��L�3�I#��歔�﬚�ЙD%�M�^�ĵNth5Xj*��f�$�`�2�3)���<�	)��I4� ��61�U�i�V���a�U�h81�&w$���H�wS۴�r\�����	��
�C�`��X%��j� ���=���vo_PH�$���Ֆ�h5��2���X#�&f1���n�y��2ͦ��0��Hr�܊w0 6(��٩OvN���bH�럚�U�	�Ȕe�¾hf��h[ʗH�I�B0����O�U��5���;�ZD����7QO�*�o�c��.�P�*�z�h��e��s8��qD;t�c&���u�$��Q(;4K l��w�Щ ����S(N��� �/�(W�c����^U��Y#�P|��˯hY�&����m�Ox싰L"9{iD�?&��#a�Ǉj��O�p�+�$�CT����;D����}^��Oϋ�L��ڞ@1�b��\�w�q��U���Ƹ��V��`��a�K�4��)b�z��Da5�Ȭ�K5�4iB6I"5��u%h0�QN	�Z���Zݕ.�|/�ĶWwx$�˞����MHH�<�$�&Vo�"���IiR��i ��#t'�/3�7��S^
�H����h*��X�N�	#��6�	���uP�6
}��r�]c/4:�{'��0��r�Lx$�V�WM�ź��d�,pc�(���-�ж��,�^I�py��Ha5�ls��PN�e1jR��u:K�krSN0�/�(�%M�$*TG�9����UP�������k5K��^�EO[��ǘ6E����>�"r�ߴ��G`d	�r�����JTN=�iJ:�<�[_�|j5�q���P��yժ�»�e�lM��L=���(C��2��'d�)�׊�	��Gt���C�G$
�i�K��YzE�7�&�6
�lu8@��~���g�3u�Lh��04�@�L�NA�N��'�-�e̀�Ӎh��:~3��˸�����Np5 ��y����#�2XƸ����a�R�0�E�V��f�P�/d[6��s���Vf�3��$x��{�u[s�@�g���gp��9�U9t����~X�:޾T� $½�^}����|�x�T`%��.Z���}���Q�/���l�i/`�H[�ѭK=�\"*-�V���hڸ��[)â�%Ox�)�SƝw��'|>�'
���Kǟ6r��:zh��=2*(#lY��b��y�}7����;:�?d��!�D�f��VUM�oP����y
��5�h���0��<�uS�����U��X�bY#�����
<��`���`�Q�c�G���
�	�3w%� ��6�S���{�]���&��ǈʯ�
@nX���+�;<8�ޘ35]VN���Q*=ʀh�r�R�Ed���_N)鴥[�=7��%2��.�B�fv*���d8<ҳ�ޕ�*�����eń!6���M��lDd���H��s���=�W��j�՟%¢�st���F�˶�Y��E����Ą�f��QD�a~ ��6�ݭ��K#?�T�n\���ƙt��d1�l
�Y\���e��
g6F,wk5�<�`������8c@D=��*>��]�����w~�%TY��Xq�i��f:�M �42��mxi�B17j��_NYá�V�z7�]��&��b/ŏ����Gg���	�^f{z�LN, [=���d�{Z��ɸUg=���$�ߴJ���5��f�h�E��^��o���@9��+��1P�T��"�]G*<q�I���cu8);M�k�|1x�l���h�	ލe�U�L|yޭufo��+n����IZ
H?sD�(�u�Z]���
�%��΋8�`ى+)fҶ�|+�	~ ^d³�1;�K���2�Ca�O�T����DH%ا���� M'R�/�P��t���A�L�S���50D��2�s}*5*�k�p`A��F�3�~A8�
�j���s.��6T���+)�Z��ǇK��R8�(e;���
U6ƍ}%�~��@ԃ0˩FζE�*3�_�,mf���7�į
�Gũ��4}?!9�Y�U�9��9���Wn�,Tw��%h��GG��3���ܓJ��Bմ�+"�7<�҉#��}�s)�O;k����(�tT�)��\��Z7������� � 9�p���C���~�[և&�n$#5TI��`_m�(�s�[C"�c��(|Z��Q�~<��-fq>_���ަ'�K�w�oV܋��o���;��d��q�aQ�-֠�'Y�G]���G'5�8w��ΥHɑ�_�J��RLej�n��0-!��c=n�ż���I�N�1��6fY �n�G���)Jj'B=�=�)�Ay�aKV�w�/}�#G)�Y�tz6��<m��`	�,M�c���E��{����ʻ�'U�V��������yf�2�=`y�ZB��3m�d�Β#�<�pDW>P�-Z�R9~g�iӧC$9K$�y,6��/�y��n��z��f�rY~̣���.�_�j��� )H`�DAF����5E#�b�rd�w�L�nB9R&��2mڐt	�h������t`p�\�,|8R�	�V�TE���rnf�m��n3|aТ0Q73�G��0p��P�ThI��Y'	Fl҅a�Y4��tj����z��Tx�]�%����b鬞	Օ7��4)���4����q���v��n�E������2�WH*�Q��0Dn���|f�M�ф�ǉ� �I�6n���y�:�T�!��Px���F ��{<��ŋ�=�6���8/nO�Q�*g�����/èʀ�ut����LeTc�|$�K�ѥ�`#"Iy��QA(O���Z�U��xDiT(�0�5�`T�꜑��:p
@�g���z��Z�Wo�)���9^d�9�Ald���ڜ�� ��DQ��<�Bi�Uܕ�����k%̰�    Ӱ�Ҋ*�oQ�9�<)e��������iq�G�2K�����,!c�h�m7q���a�px�����0���$�X{�Vb�b��2��b"%��8����DI��8�G^K��B��ޫ�n�O��:�z>��D`p��z��K�ER6Q|{��(T u��M�✫������fX-H�A`���3���Dᔷ�#Z�AM3�����.r����F˕����b8��������D�J�m UdEYN��0U-��<8���C��vV-�	��L�M�`,�9V��ت�/x!��UI$�:���[�G�1�a�L8�ej(�0x/�=�u�_%��{�c�A��q�A���W;Z��� ՚ؽ	P�/�~�b�C\l�5"�(�bB���ISD���^�J�p9}�A�G�+7�����.��v>���A,�s.�|:IQ�qu{��e�D�"~^oW���EK��W9pN#h|������Z^;l�?��5��G���zhu��|�E$^�,l>���ɪ	]J�jKI�Ҝ���I�<P��GĚT�ON�>!эR�@(g���kc����ئX�*l>J{ѶEv{�����R�n,�W|�{B"�j�m�5�E��(p6P@ѧIu{��AWH��i�z��㞌t"�D�D�����p��J@|��*ú�'<ti���)2{|p8 ��
� �΂��'!��<�)4ɶ[vR9Ų	��H�ĭT����6H�q9mh��[7[���Mb��Hc��GS�����Nh� �����ge�`,�I�U4��l�l6��2����B0���#�*�~=m%H-y�����3�txPP������vݭ~T�+�c�i����5�� �|�M�M���H`B�͍1Z˔p�SG��m���*�Եu�lJ���]FU"�ħ»n!����YYN�ją1�:T��Gl��HY;�Ns��C�m"V��Z���
���b���J����	]t��,9���!4*�Vc�	:����'W�<�>�[Z�ְ�j�ɞ��z�?s�)�ރ�j[*l�{�6&e���I��'X��v���vj+As��ߩ4z�%@��l)�PV��ۘn������71��Hy
e|'��
D7
&�n����QEk�d�1ZL�}>I���Ms{i���]J�2ހ���E}�LI/S����^�M%�=�
4��bT��#U����\Ȏj4��U��z�H�7p8�l�2}�ڴ���z��i?�k�v�Xߑ,����T����5��+.�zNK�����r(O��QX���68��-l1��=x+!�
�8��YN�~6rU�v�U���NPJ��:�s�)�w�R[Ց4��b��=��+�,s��O۰�?��>�K��I#�Y��7#��4H���;��]�8�g�!����l.$U%��Cb�H���<�]6����cD.��ur'� =<�0��G{���W3hU�E�K<>��P�)�VqQO��$Yj������:ڛu���	�;�R�����w'>�`��������/���`��i��r�V�͞�����GsI�~�~!e���tu�n�E�`��UJ�YI�(�ܭ>��@n7���gxӡ�*�SF��"�J˺��,O�E����Bjn��GP�Ea T(K�H��;N�ـ�d������.��z�����S�hIf�u�`��D~��v0���Pn�Fi�w6mDI�)R������|&O������:[��kp?�mS|��zj�]�[@��'e�l�JL;�o
�
�:뫑��.�07�G��>����Q�FO<��"�V�x��p��0�	jl��	�H� �D&%�y":���v�yA���WqV�w8��4fӨ2c�	ٻ(Ba�da8�p�X�Ikaq���Jp��=)Xp5��Ó���]�V�PҐG1;(�>r�o����Ty\g�[&i��M�OD([\tEO.�"�0��K$(mv�H����b���U�i>aP�
��4�$	�"�H|Ϗ��}"���
^��N޲��0��b���L��M�۳G��t&Yh�����s���ajg��WI	����~��UYu�iX��)~Ue �b�����8��Y�v6^OH�'���0�ś~���d>���R���'���&�����=v۠n��s��{#`Vq\r;�{| �=c�e�:�'p��)�e!A~b*eӟ�z���{�����S-�]s���&�pC!*B��(�j��O����&��fBHM�sW�.̓�D�_ f��0�c����r�5����6�T�+G��˚o��t��J��0����B|z縣$yC]�޻U���DeD��_�^��YL�|6j����d�dF�P�H�d6�V�##��H
L:'�rҹ;�>m�':�y*�IՖj+�=�q��EW�݄Х��UdQHiK-�`��>��av��	\,��E��S�N�n��"l��8��>��	Y6͓X�j�q��гkD���tǚ7���̆����L�?�&C�,J�/��z.�Vvn�t�ǎ4��U'ث�+;=*3�!M����n����������eEع��H��[N`ODL��`/0�\h"�cK		�L�&
���W/-,/�Y�IRe헀�Zծ�
k�挾�}�`s%\��ѝ?�i_�NN�>��D����H��;o�=h��ig�W����`���5_&��2N��7�s��,C%������ɢ�Q��^B���&�B�=���٣	K�ĞW�I�n��%_L6c>��:j�lB��%I��^0��/O#�ۿ��S�#�=��Ft�bH�٤�븊�	Y!+�P�P�$|F5zu!N�&؂�S�l����a���Ͷ�����0[Os[t� )�Ue,���$�Y����D%_
;a�NM�N�K�Rm9���c8~��E}�Y���S����!�}��+y�W5p� c[�N[�8�4�ǜ�Z��a0�o��x�m� �O�	"���,�.͘�L߅����2�r�q|�O�%'��b�,�Ӟ��l���E�}ر?�8�lA��NAc�#h�¶�������tim�����6��߹?k��0L�~�B���A9�܅2��E��3.��uu|����M�D �Ղz@B��ĐU�J�W�a�x�Ў��L_A�N
�uO���׮ 9�q<D�H])x��%�K���՗M�♘x�i�̷���T�i��g{�d1���8��,�L�Y��MN�|n*]�H�tP@��-�w�6�f1���2��d&�l�$@I�����@ 9/��;����5��ꕎ@��$��kI]<�H=G�E9�X����]3�y+�&�3u<��-�
�$�X��P����&��w����^�g���b���ʖ2����~űࢲ���sa�*�/8�����c�=^~�=�(���˥�����8,�R|l�q)8%�1�u��!0���[�ƶ�D���bx0s׮H{����՝�[����$[l��$i>�Yi+3A�ɤ���dq���b�Tm�[\�Xos�XBɀVH���!]l�4��p�g�4�1I�5l��U����ypm��i�� % q/��{f�Mf�W6Q�w���M�D
fK���:j8iI����E0:����g~�۞�'�h^2��`� �vY���ں���iy�`���K����G'��@h�(������D�6��3%�:��T�^H<�D�Ӯ;?c4-�?v�ќ��#��+���#ֶ�Sn�%��w0l����"R���[�+�/���Ԉ��8��m��D_
K�~Y_������|s�|&^�T
�G|��9� eu��4եAO�����?�b��ҡ�J/��nj�$Ʉ����$�$�I֣�յ�gK��w+Zm��~Kz��:uރ&*��|o����Ŕҡ������>k�ڍ�p��Wb���}��n�u�&�`M�q�P佖��`�Ư_��I�rq����%�i�C�e/?����x���Dy��c�P��r$0�-����gSkL��^�2��OL�F<�9V����Y}!�z��L�wꔮ�3z�{P�$�b��    �z�&˫b��=Q��]|���(��rp��b��1���ve��J��G��C��Ɯ~P�*8F*l��w��.�CH��(oR>�O�Z��ܨ�C�4���� ��t����:������^X�C��1�V|gZ��gM��9*+an@��'B����%ڇ���Z�RU�#���q6���p�Ԙ�����L�?3l�Ҙ�}�07uh@*(:� 'i�Q�Z�㤚�����\5D��Nfaf��I��+�A�����m��yn��yTo��~�b��|��Ma_�bB�JR��9Ȁ:��LTq(S�h���b'g6u榰���o\��˰e�I�@^�P��q���o�<z�}��5����|;i �P�a�v�Z"9��oP��M�ܾ��0�,�{����WB��NA᝶����w��a�ɤ�� Ar��M���˦v�!��5d���6U��̈́�5[��(x���[�	�����<8�a��$����P�Hb*��3B���M���6u�O ���%�,���H��<\
�����J���؂���&L����j�#��Y�v��7IM��I�)�(M��WQ��w�(<�]���䊒n��;�%�Ol�9N�������\�f<z�I�	G/M
w���k�o�RU�R
�O7�
?�+��8�	��Tww�B6{�J#���I��Ԏ�j��ń.��چ��m�dx�����@]=�!$]/�����~V��j���6߶N��f������i;
��{M�	!��N@*Ŏ馬����W����P�2�)��{/D)�mk���C&󃒶�P4`l�v�n��<�=D��.�-χ l����O�L\M�&�?W}��3}(��R;��/�[F��]k
��S�-�S�����O���a�M)-m�V�a�y~�l�\�?��@
7ƶ�"Dt�?�^���x]a��2�d�6��G)��5 �Hij��A������ipVR2�|���A����(�	4�S���š��OXDa����c(�������F��k]�^Nͻ���E�d !�'�ğ.ު��6�bJ1��ڨ��	g)�CA=�9�%�$�ч�~� :B�,�UV������� �9T���<=6�O�]�s8�źz£WD�R]�"�w)�)�����8����r�ag/ÿ/(t�.�r �8�_	�M�����ʨP���>�m���S���G��"#";��Z�M�FKC玹e�C Z�~��6�	�ey%�\t���:U(�g��uBO�v���"2-SۘM\�͋��}��G��6�(���g���E9o�H����$�l�UQ��R�m�����X�6��qk����<�B7�8xUV/Z�m�P���S�Dzy�$���[��U�'݄`�j���K͵.�㰥r�p}�2#J"7�뗟o�4�&�?��J1k�@�1��ۀ�X}밫9	||S]e;ם#TA�S���\JF��Q�,���]����7i>�̖�Q!NF�1���t��\݀����m���3�m>v-�*BʤjԈ�x���~gc޷mN��M�+��d�O��n�!;w��n�٣��@	�g�l}�,W�����"<�9�͇�l�&���ےH��&H
R�g*���\�����������'��ye��"�FBc�ͱ�M�М��(����v��y1Q�C8aخ�U�P�y��G&_�Zc6%�.j�pos{��hJ�̂���G�	|�{��x�Q����/��$���71y����S�0�(� ���0����`#-����P�߰� �Hn��,�r�]i\��O���;{o�R�Q�]�Z�����Lm4[�u׎<r@
<�_�R�D8�I�gaٿ���﫝��S�ci���� (A���vq��.��G�M�O��8D(���)�iGoa��������g�h�f�$����~��Km)BR���8�<q?��*��g{{�� ������{��_��m�ٲ"�p��$W!�,�r�N���/O��'�����Pn�N|�HO�;\�Ş�٤�:c݄g�,�R�,����d�&�T �*��@��51'@DW_unu�`B���7F�Lg&P�05���,����i��i8�k�7FG+�)K>>�Ť�g�]vY��݄`���Rei  ��ޜ��;����G*���L"��~�l�./�	��"2����	�q�5�}�m���1��0�����\j=�u��[%x	����MEP��0�?EƷ��8,\�Ȃo��s�$�]���s��Lv��$�A��8W �n	�"��}�	���*
fs�c͞G	G�!�vR�E���â�@E�bd쫪��bɷ� U��E�!����j�c5G.W\س$���/J=B��G���k͒�Y�ӄJE��w+��'��9"�H�.�p��䄙Ŵ!fs�ʸI���,L�����y>/XG���e�+�{՜R�%�� �"ܒe��fs���>�&��$�U�1+���b�.޵���ݝYy�`AD3咤gy�����׏��P5�נHl��J��k���.ʝ�:��#%�b�æ۬
���@��b1��ٖ�]]���z��i5�8��܊�r����hBE�~P�R_!�*ト-&�2cĚ�4ل�呒��(x�=���Ep�1��&�:��=)9=�?�(�|A��\����6��!3q��F4�u�t�o��\z�N���E��4.��M�s�A袿A����g��䙒��$��{O�XE�zy	%ز�2ę�k]��`����l2�]�Gv�E����TD $���fI�B0ƍl��"�6��3��ݚFZ�/S�&�q,<�ɓ�:T);��b�dרȉ�>��_�	$��4�u!L_Eۯ�ۄ������Tv<��Eؕ���	�UQZ��Ȉ8R�WQ��+Rc�]m踝l������:�ƶ�����qs\�� :����~c;jO��M>'�<+���������e�@I�@��s��^Ʀ�P�q�j~6�g�VL~ ���4o�j7�t��o*�*ʢ~���]��Y���H>��bZn� ��>ju$�0��c���˱���R��W\v0�EQ$�����W��x�ZlZ �8PF¬׉��~l���W��R�n��_���� ן���#���I���`��{��,��=o�7IZ��24��Ee�V4��[�^�a�<O)�|vGU���	��Hײ���r"ت!��̅I6��ń�w�y&�"~�;2W�Z�� ����nшeU��cCـ����<�ϋb�Ĳ��$�W���&�s�l� fMo7}�u�vp@k,�-����M����ЁD6֘Ϗ$��~����K@�EUM �q���*|�&�������4�'���#�bWq�E��I3���LL*��H���6��?B���!JUk�r�x9��\�U_����25�yT��G�0^@��z�D,;<P^Ty�b}����se����$g���P&�&c2E�(㟺�:U}����D�{e�ޭ�K`oϪ]|���|��}��݄�(+J-4�,�	�>�3�0w��+Y�S̤�ҩ���=Bd^��	C��'�ܖ�z����m,�:�B�{��=Z�	���V�=�VgTi0�|�A���X_�܎%4�,35FaVM���8�eY��x���;��ⳃ�뽠����j�邆�-'9n��m�)��W����~{>h�
3X��p��`�����im�Z�n�u�gr���`[���˕����"�L��t��OO^͋�:�E{���<�H���3"���Erػa�~��ĀR|@��8Es1cL����H���"����/|@�-h�
0tm%1*4�e��L���ͫD�fi&�ض�
�z��x��!7 EG�G;���	����������h1��\��&���kR�}Ei���2	T8DID"�j�n;�dD4��m������vP޽kuj���mb�z.L�	�.,�ۃ����L��.W�7z'-՝����'G`�
��x�3��F,S�7q��W"����(k�9����<�C�    R���	�7�J���Nn*��?�+�b"�E�#�ݬd��؂Nz�2�a�.j�6���{s�BH�&�6���f�X<ӆDd���xFsɑ���|�Kf_%�y�����]�BS�K�o����+?��[\>ψ�D�@�g�w��գL�4I4!���t�A�~xAw������v��RT�m׉�P4��e��pJP"�y�z�$c�In�i
c.��,�h���}���|�r،��������3n7炁����)�6+�jN���\SJ�8��J�C9�������F��Tu:�*���Y�N�ID9G6�[��(M�'}5��Fy_ymCY����q�U�gv,�UN��1G*�@���A�r�>b����¼'�mE�oyz9�}�7�S�0'��R�v��9&����aO�2���|��M�Š։�U�S�����@WH]�~'��;���!�Ŵ�.}������h+/��q�7Yv�e�Ň����S����#P+����[�����N!	�ف���(���0��G��ڥ{\��Ռ~5$� I�w��Nn��V)n&�lw8ǋ����N�(j�dB�[�Y�'0~�woK�ޙBҴ��AQ��� � ���D�\s����u�n��kc�j�{��E���(��0�(&�H!#�sw��Jz�y��wD�ۃ�=�Z�"b���2��Y"�fqVM�X�d�4pcQc���]ʞ�!bUk�����=J629���d��L�˦���v���@.��1����LZFdd��X�k���XVid��Ǽ�'����%!� ��H�����op6��-&��84I!�˂{��ȝK�4��_=���40W� `�n}�di���Z��4�Z�WW��Zl
��ڐd�v��m	�?R	�ޤ�*�G��W/d������(�"ي�aao���赜�����y�\�#���-�,��,��R��z��$ꄐdy8�!�e����L�I�&�'�)U�<
�O����U���)������VA��7V�P�^s|#Dp�Vl>d��G���h�5�\Z�&���L'D7�E�7����ʘӑ=�q}��fFo!���ƍ��+2��'t�Ok��ͅm�A�xBj4��N�(����	�^�B���b��ŤEn��V�����D�K���M���(��<\(�e?�ń��o]�S���z�����<N-ym�[e�El6����WQ�F:�(�Ϟ��>�"�L[���n1&�l�q�9 b�,�I�R�2Qk3%Vy)��yd��n,�m3��µj��RWz/��1��ꮡ&rR1sg��vλ�b�r���.��	W1O�F��l���FD�F��;�=�� ,Ŏ�-Go#=Z��,�z�m�˛MH�y���(~&w��_�w[/A؏��dV	��a���7��$��W�G9�w�����������@�'F-x����ՍR�\��8C�����427��]-����m�u��_�qF����/ZH�u�A�GR{�m���{���"��;�n@�Q�Q����M�r�v8b#>�wq�,�k6?l����Q��-[�S���a[g�	��>�:E���7��s�+e.Q�:>2Wсܑ(�� {������;/E�V����H@�=ދqAfK+qX�픰��F��fUE�4űaX%D$D�x�� ��&��hK��aW��U�3\�����,�s/�do����e�_M�SV/��s_��F0��l[gb1ql�	Un�YQJ0#���;V�ʋ�\Є�̶\[�,V��M�M���SFz���gB����F��mr��rz� �+f���b~������h�It{;GQ$��<N�7'�����8����,Vv�\���Ӊڋ(?б���G��i���e�>�8e� m�������;�x�J��"�o�ȭ�#����d�zv���ؤ6!~qT�z�J��F> ,�֪6j�L�#/�����Z�Z�(�W�Һ	����\�\�5y��J�e��pe�<ɤ������nW�w�v�[��uW�k��A�;������i����V�����<��	'0I
m��<xw98�-)W�!���S��앯��x�����o�V�ju���p�6��5���J�ۣ����8��S��ukH�3�E�0t�G��j�� 2�y ������?��8����sE��'�p���{R��j���"��,�h�'����-?�PhY9T��`�e��8�\�mP	����Ţn�D�ӽX0������p��2�N\�t�`�블�+��m+�!���$
0�}~�I������{+��G�h��d��I\���40�4�#�2e��=�>	�>�H}ܽ*�c��ƀ�MZ*�@�D����ـ�q�%�:پʺ�I��{�v�u���1|y��J(��`G��H�y�2Ιb�Od1:�|�MUgp"�1nʙDJ�@���P� �x}�S@%[�Z���n7>���g���p��w]=�R�_ �gE_�U�� �R���2���S^��� �ES��8���!��w�ܸ�b+�CO 6W���*��KS�'���́ j�
χ�F�[��(AB�Qa[�-��5]1����	,[Y�P�I@O�ڈZ����[�;$�I�W�f���X�Hq6�e��u8!@yRh|���F�C�C�G�H,�(y����CQJ��>�����T��uU�MH�E�f�$M��������az�'�gԺ�F�-��N�#Ģ�X\�muk�#x��Ǌ�� A���R����ZL�7u�N�j�^��d�_�z�,i�.�[�_�'�:�3�Vo0얐oy#����'ao�	)���HSD�
����ҍ}:�n��TC��'L�?#6�-��-�8j��k�$L�\��I|p>�N�AXt%��(4Y�t�" �Yn5�4I�<���L"���K_�y�/lPᇭ:>�<�iH�����_��:�xmu|��-}�o���l���L���=���O��\�)a#���~V"��E�7Ef[����%}��(x{�:�
�����:U[\�4\콙�����")6id+v	E|��]�Ӳv�<2�>O��r�a��SK&��j&��&Lŕ�vx��A~(��[�j��b�/4}�G���� B��FH*��S"T��I��X�9��ƶ*�<�)A}�ʎ&��z�5�
�c��?W4t��(��e��&���>[{�i^kl�_��KҚ�����y�D�Te�e��E�	}X�cvBx5�qd���Zcoe.g�3[�tIW�^2'E�iɜ��G�H�
s�B��Voږ}� �'��]��7�3�>�t��U+A�5�Չ-�CAp3��o���Q�N���;QFNZ��[���k9O�k�=�D ��i&�L�=!��Z�S���G��	�ml���XVVb�a��?J��{��sh��hj"O���-rgݩ D�NG��R�З��z&��g�y�R�U1�tH~��z�>6�dibC&d�q����r/��$��*(
&�ĉ��&�z���H}Zv�U/�F�N��������9�i�L9�.���g�&\n��?��� J�X��Ȥa[M��a��PXnl7s^=����d"]�����U����7ۑɶD���Τ=jLe��Rg�P�^8Fx���"����Z{���]@]'H N]�*�԰if{Z�{��H�]�=]t����t?�XO�Ȑ�!_��/���4c�l3�,
�1�V0Äc��`�BKpB'CO�|�/*������k�4�L&��,>B�� �O&y�j��ET�@�߰������n�!����r�m`#.Ϊ�w�JR0b��d�iH�7ұ�BYj�t) ǨdD�T
Yr�+����*�<d�p��#������Lh09K\���UFwn�����d��Q�sxaF6��Y�`���5"�w��,z�ʚi�?׌��APY|�̃Gk��U$���3�����:�P {�l5R�r®i���~�?,�M&3�,u��j4�@�h
��S!M�q(/YD�C�v��5c�
>�Hø���\��4Vu��O    )!�8�z�J@
��_�7���`�m~�jQD>B@E�z�Gg��yb�ڟ`����@Fx")0Ų�@�B�#�f��p�8:�BB�P��w�Z�����$����<)�1@�+�F���y���Q\��GN(+uG�.]Iɸ)[of�n%͢t�"����!�,��v�������w�վ�)o�m�0�:��YN�=�l�6�'�zsY��Pe���{��T��ET�	V�o^�
,�tG�xD|��ڈ���eʙ���jF8m�)�����Il�S��'r_��Lo*�8����3����͝R4��8�(�!L�ɩXB��a�Z�E3ㄦY�[���\셎���o�-�3J�0'S2�iFf�t�Ԋ ���SY�U,MT�h��(VQf��� ��A��ۿj�؞���a�R����ɉpC�RfaL��S'#j(���
�[��nӁJM��3�MV��o�Pk�
�T���^m�]�x\u���6�Y�V}�eGZ���>`y�i�ɣ���5xI!���C*4���WŎ��f���<��t�^AEu���r������ inb��q��ٙ��@i�8�2�PFBɍ�\��+Ҽ�r����@\"��G���� i��f���D)my��T,]{������rGG������m۽�㓬�:Cc�m��*�e�H����D�4�F��H9=��@K�5��;��N�@D��둥]��s$�ä�3�Ｓ�%74?�ʲ��I@N��|P�?�CDn=��b���:������U}yi@�=���F
��+'�ٔ���b�Q�����'��W����dqX�׃'�()u�����x<������(A!E�e=�[���"��K�뗽6�F�̷r���������V�p��
�V{LcQО�����\m�]���_��?��x�|�$).��YD���K��M�9�-K��0x�q���ݞ'��o���@u��8�x�$/�g��pr�q9��gtbY��[L`�b?A'7�UĎ+HL�) ��{��~ ��|.�^0@����o������(#n+7�R/�*�奉��ǰ�R��"��j�#b0�S!U~zh�����>Rdu\]���f���@�YQ�s�����E�g��H�d�UO{�+���z���j�r)�l�9G˶���4�
\4�6kޖ�A<?�L�Uۊ}����:� Y'�PE�V3}Z̊8˪8�f���S�Y �t �0�"퇞�1o���l��`̌�7�_L]%��l�;Ef��D�\n{�=���oX�z�2趃�`x{nxx e�-E����]�ʵI��8=e��~�����C�/z� .��<�@~�ǻa��)�R� d�Ia/Fʺ:����L^�&�(me���n�@�a��ln���h~:锠�7�%��������sb�G�GYM�w�>*���~L���]/L�;?TE� �및x����"�r4��������}'�>7�X�5x��~�dxC�+(6�� ��	,g�Gu:�;�Gy���2����' Dʂ���7>�`		Z��_ԣ�ɵ�TMR�#�/h�Eکx�XA�	~�愂<��p-�a��]�uB�D�
"ZI��'n	4+H�0���"��y		TT%��N��w��Ce{tZl��  ��V��ݟE�j{u�N4��~x'�Qۜ����N4eq`1	A%BH�
���0������y���<����4��y�|�R�I��u���;T��8�v���u5��|�<��p�{�@d@bۼA�Ͳ�2B�T8�\Iq1Umu���F',z��=0��;�|��<��j�iK�R\e��w�@�%i~�\x�;�m7�YIW�����e�d�?1ʶi�F.ņ
mD��b�B�~鴹~,�g����]�ߪ#]?��P���*�p�CN���g�� �p%��QC��&6��E`n�K�2��`P�m�N�OJ��Š����v'���j-�r�yUu�����
}���X�C��>�wտ):���٦o�N������d��鳥�Ax�e��{���3"y	8�Į�IK6��n�,{-F�ѹ]�R�N5�E��|��-���u2���,V�tYBwZ{�g{��f`���}������[Dz��u1�v�'���#(�,T��m'�imnd�d	H����~�e'Zm�u%OO�'�
�PTܮR�=����{��B��1m*`~��0x���^!1�� �=����[��������u,/���-��Ó�;���pd�l�Bk���l�8�;�Q��A�f5���X&��}d�_�i�#��T�����8�86��ꔵ��h�5�2n6�J,z�A}���M��1������ִ�C��D���
J�c&�6F�θ��'�;��a��ڡd��e��z�
��)��{�H:�o��YĤ�+�^Sb���a��z >�٘����E&#��	gx�y�dQM|�$9V}��U�|����r��y���>�� Oo��+����%�m��P��I,�.L�T3ҫ��*��� )i�c�:����� ^ �϶d��\�e���(e/�o]Te7�_�w[so|�W�n��3t�\PH=�E�G�~���d�рh�]��c�[9Q�ߝ��p���Z��@`p�ǎ�G19U���T�d
��#�[
����	�ꄱ�$��!J{D�W�q��=�n���=��%�eT�x��|�����uf�B>�����5�2�e��eL�*�l��)��0'W��8`�p����|m���R�f��<��b��=�L"|�I� ����/_ਨ˦���6���������ܟV��� k�3�y��G;��1��g�M��`��k�yxG�=:V�������vpNO�zۋy@��9.fy&��L�C����ݝ��x8������+��`��I��+~�zE!\�um�)]T���)�X�7e����sKx������R�����^���
���=k'�0�w�~���'˕~}3�ZFI(�2L�O��NU�%���h4	�z���F���	i�s��0���~,* IRBX���ڋue�'3F�e��(�4�*(Cͻ�㹫V� P/gD.��8� �)m�+oG��Dp
�hl�7��̮�&[�Q�ɼ��<T��,���X+�P�������E��
6x�&+M U��0;�pJ{��� 7H]lR����MW+���IYV�w��_MKy��.G���ټ�PG�C{��x���d(���u�r�_e��ŌG4�w ���1u� GS���f�z2`��P�e�*��D*�����̓j�̲��'�!%h�:��;kƖ��Tڔ\�/��,�d�\��㤈$B&x�n�"ZB���-�'�-�\�E��OO��$O2��]+�T��zk�Ŷ�e��3PenrN��(�ֈ�8��\��c�`V��ŋ���h(�M�KS�3�ʢ�C�-���O�ٖ� 5#��A]m��eNNմ3t��+eZFq�^\�:���IU(lY�qgAe��%2B���'�����U��#�t��X�G�Ѱb5{�ޖ�˄�	�nFUa۝L�[|d�z*�R����"G9��Q��Y�Ct��d٦�OwFF0ce�9C����H�x*�a@7�z-�.���;u�r#��J%�}�d�H9�w=:�b���+����m�PmZ����T%���0 �b�F �,A|�Վ�b��e��3\~���S	O|VOh]�E:I�눃��Jڤ��
�L��Ul�W��b���j���XsEx�G�锶�\��;N�"��������a�o�c*�"'B�}GL�ն��Is�8O���^�d���"pWX|���Y�E�>��ܡ/�p��,6�3I�h.��t�ظX�����˓����X�]r�Ĩ\�ﻘ����cF�o��q8wvA���ÛN)� �x�;��|1@�"dr�iEdV�u[l6i�4�!�l�(e�G�p��~�a'ikRǌP֪C��{~�@�&K��<�e>c(nr#� e��,��    IFR,��GOYW�0�~���ZP)��K�|��-����/Ac�po�m.�d�j�-C)[*"�Bx������&]���[>�o%�"�:�����>�yKn6�<R��0x-���@�T����R����k�R���,��-n6�.з>v?��tI4���O�=B~f������.��y5����ʷ��p��P�r~)��6�X_lʦNf��Hu'��cP�d�DTZ�֕=Opo�-�=*��Lh΀a��$I�@0��)!/6{3Ub��]��:�S��v~��u�<��2�y~�q2`3��>8���c"��j��b+S��*�1q�^�,�GG�g<��PB�{봪��G�^��laUx�����U0�!#L63 xƘT@�e��9=M�Q��{�v4ym�BZ����o?���،"a(����-�aO){�v#��j��b@��������uC\�gB�эFx��b�9lΘH�ά����Ux��jp�K�.����b�Ǘq|E
e���EĤ�9'�Fh�h�E���Z��FŦ�vƙ�
{k%H&������-�i�/�ØM+*�O�����0��4M�E]~}��$���H��+�H��q����r�
�\rR��Y3�X�Z�M<���&��RK��]{�&u{t|�Qxj�������	�u f� f����$
`��J���њ���XO�p�	Re�x^�$�t,���լ
=8L��-�O��6r�]��������	h&�*+����h�6�;�q%3�fb
q/-�Dm񨑾��וi�n�J�m�î:�����0`�iZN&��!|�zϥH�U�&Ɍg/͊D�g�_�͌s4��j�	�d,���Lű�6���w��m�Y�qz��rv	Glj*z��~?�&�����<HDDz[����H�?�֥eߏ0U�����`.����r�_���QٚxUԩ��!F�+Y{~?�B��(T�
ÿ<|��,���@ Äk)��������H�r\*}�:oF?p�(&�j��V��Pר�5���X-e/��R�q��8�Y���=�u\��������=��2"moZ(���ї#sGCr+��ے,`?��R	C�?n�\���=E���dߠJL{�H#�#RAu�ٱ} $r������F`�}�p��\��wh��m[���%b�uyP"�t�p�7�/;��H��%���ԿC%�(�~�y	EAwm(�����	u��q�0](;#��P.��o��W��U�@�6���l>`�����L�=�/�����}�^�/�}������'�PU�2���4���-Ԗ����$X:9P<B�T���T���猻XXe]�͈Z�L߁"���i��i����O��3	>�n�)�^�����ÿE��#���N�l�h�������]�3T�M��xi�2Oe&�����(v�r�dG5WF�k���M*fs��p�	����M��PC�ў�03�Qd�3M��hE<jp��
�X�d��Ԃ�uH�X	%���-6o��8��iA<�v��E�A�{�~��z�A^�{��6�
yI.�ln�zW��]�t�5�prP\,�X��>�4�6`,j� ۚ�Y�Ľ�d�r�6�XL�*L�x�4ҽjb�7BLҬa�)��Ƣ��Gڃ}���O%���(cJ���û�ϭ-]5����ӌ����W�����oc���2��s�LC�ר�Ԑ�A0�y\ˊ�Hw�ch^��2U���8m$�L��(���rxO�w)Uv�X�p5����~������11i���4�ӯ˩r�3uoj���2�%Z��tB�R�<�&��>� �@<�yP��/O��.M!z�Ö�"��=Y����buNS�I�lI;J��q)�Q-����B����@���n�&3V�:ldl���`l�+�u|eݝ.˱�I�����SS�μ)��MkJr�T��p>W;qQӕ˜������Q��Y]�I�h4u��̈́�O����j񈣂�km6��Mהsbd2��2���m@D��я��&>��>�M� K�c]�%�!e�K{���K�f��X���ﮏ%@�z޲��N�Ov=n��|ڍ�x�r!$�zV[Kq�����_W��4��q���}�Y�;T�WW��h7R�V`5���Ԏ�cĒ��:����R�N��^��\�ь�+J�2�3WP��?�u������HWS$\΍���0��̈R�2�O� �lb\����8�m���%�+Gо�kZ���[�[�Y�x�2[�f35��;�4��}9ո�Z�pD(��X���(�LG�_~aQ�a^�8c�IP�������Pl���ݍ��� �Vfs���(�����~]$ux}y���,
~��MD�O?�e�?솧�;�{�g���0��
����*��U�s�`i���h�FF���P>5�c�>��)z�6�������w�t�eV�K,V{�&����4��Ԙ%��|���{Oȫ
׳��zX]����#u������p��:a�,9FI$�3q���������[��Sm\�.!�@��#�<q�)��S�����|܄��R���V��w���۸ �R�l�G?��Ӹk�m>�=� +��)��$?Q&��z�苧N�ﷀ��uRѱſ�k �i�ϪE+����z��_`���(� :�8��u^u�/4#��$�f�w�0Y�����j�޾��DE�6�^� �=w����fC��$~�J^��h]�]y}ʍ�4�
%˂ۇ�[C��{�A��2#Έ�7����'?X���e�jج�RKc��z�m��B����֭]ļKt�^A �eB9���n�*2+�O��$�>)s��E𲵺���L�L�ںl��3��)�4���0�: ݤ��ێ2�2'D�W�YL��J�^���q�j����G
	P.����8���B�J}�z��>�f���X��r�=��p1/�m��*�J�I�Z���+@���O7V����?��Q)���J�M�E�K��a&Q�m��5�эy$IrO��
��������@g�U;�ʳj(I��k��w�˸��
�ވ�Y�i�+�DqW�G4�2��#��1ێ�ˑ�1�����<�:�.�Fl��lOF�sO�E:���<vj*�o�Z�Tq���
�С��]`e�Vm*���	�:ȳ��@#'�S}{4�*����$��&���.��  ��[7�İ��e/�p<iu?<�4�'�a�)D��O�T����jD��>�5�I���X��归6X0�23a'2���0�*�R��]
v*�@O�wc��X�m������e�y��KE�%0����b�rv[
����W(���`�>r� z@�H-N�>���������Ԁ��5�=�P�\��X��":�(3��w#j ;��E�,K�p�Y���[��sC��엣<u��A��<�\�fﳐ�[�+u�ǩ����nD��!�R���:�-@������#8�o���`����ʼ	8���w�k⶞�Պ�8/dV�'��k���OeG�`%?���A�����R1I~9���N�0����.5�i��L�,�X��<^ٳԍ�$����B�C���\7m��V�f��Z�_n�����<qzqy���GH!��BS7�!inû t1��&+�vF���K�� ~Ķ�\ ,
��-��B�t��:"#�Re����d@�$3�"��&/�+����R/]�a�8;�Oa\�N�y$�՗�%�.�=E��a�^v?�'��YQ��an����j��	OQ�m���f���h5 ����"��5qI`i���؍+th#c�Q�+f��p9=��W\�߻$�1e�^?�Mn{a	�	� R��f!JS1)�l�h�=��h	#^���B��Un���N�^H�f�Z��ɵ��lY.	�8������"�3�t�O����l�#w@����1��'���h#�Ζ�w�4^��*t���p9o{�ܔX�,�iE�S$)P��l�'�@��|��c���ت�kH�W�q�`#^�w�v�9��    	M$�*b��I"[FG�,��� ���cV@N�vG�����l>C�H%�/&��g�x^��N� �N1�&�H�hBhp��˗en��ʮ�{'|��,G���G2�@�o�m���󉑝<yPO���aǿ�����Xm��+�%�m�>X6��#Z��7���'ʈ� ˓�v�� ,�j���d������aR]<I��E�fW��Y���1D8���fKa�(�W*-�P��m�N:�P~ĉĕ��f �=K������[�b5D�r��6��nF��2Wݠ"~c�+$�@�,�	]VO"���6 [�7h��̕��I<I*:������v:^)V�C.�\k�2�g�Zyi�X����v�c�Ƒ]ߣx��^�U!ǹ�+\��d��x���t�?2)��l=;��p�m�۶��8�K�TY��;v-zĶw������8@�9�|���Ԅ��Ehf n�2-�ɠ(�ڒ��wS�ۉ��l6��q�t���!(Q�.f��̯�#ܵE��$L��� ���CZ����O���'� �M�8L�_F����ih�����>?z�J�K�)m5�O�~��������n�1���DO\~|9O7�7�m^Q ��HG���W���x��͹dH�>Y,�Z��3�'y�E
mL7��2����S,�kw�8���2�M&�W��p�M��<��*�1���[�e���|�#|����۲��/��21?,�0x��6��>R	���8i�ȿ���[z�<����Ar�y���֘b�2����^F"r���~��+4Q.)Tۯӣj@ʒѳ���Ǖ*f����- W���XL�/w���Z���$���bF���e��2D�A�U�P�(*P���[��o�*�g ����$x�p�Nk�mL�bn�;1%���5!����طMQ׏��8̴,)�����Q�Dk�����Phf���l"��u�9aDj�P��Q)E}���rܠ4��&�j᜺�����z;@8�m�a6I���&)��d�.�X�zh��S�dC�'g��`@.B��Η���S!e�(RU��&�p����Y0��(�6n&0�<�յ�������r'��:�Uk��Ԑ�/� @�`��3&/y��N���4oۦ�6�fE��:�_dt����!�jo�bn-�_����$�t6Y��T=��H�F���NI�r[��|?|����S�F���^q��'�J�y�/����]�]�3��$/BY����?��b3���$(�l>ٸ1�������^3�β훴��5l�02�,���MR��Q�g�
�M��_��l �`@���%��xA,^>ࢳ����J�"SlAi�O��U�5e(�R���X�{Zg�Ey9c�fq���	��t�R�DL�t����hZň�t Si�s�[jV��Y8��f6�il��=�x�	��<����r��-J+�0�B��lj�y,��$�vL��N&r7��ٿ,�|uI\��!�V'6r�L|BO�$�P࿾z��ð�CnSx���S��}aF����I\�Q]�Im��Xp���jj�`^��T���*���'%1m:嬳��
��|���p9�+�8��i���n�s�N}�G��&G�'�ά�H�ܪ�˚z�U,�,�z�d���<2P��;����'1�Ew�MGU�tS���;R�A �ڐ���ˢ��C�@��pj�x-��23��2wg���6b�r����l���/)�0�FFx"������z��l��ƻМȞ�!8����jB�˭�"�g�@S��y�"x]�*�<��NT�z���em�Ŏ����/6�����>#N��&_��/f�ەI?�ǜ�2�!�)�7���� ����:r+P��ԁ��ˆv/C<A:�n8��jm�r���dez}V��,,�h����#346������؅����|8�á<s�� ����5^ş�"Gi�z��u�"xۮ*����;��DΦ����sT�k�/@;��y&��Z�QP��X�}�m���q��L"�W�y�T�꬞sX��id���}u��=*B��� KP. �])�2T�u��*����̨E�m��_��2�fS��� �Y.�&����8�=`�0ɨ���}שm�ȬbX��m���Xo7���kmyt��4K���$hI��ݑ��vAg֞'�:�|�d�g�B�Po1	ڮK�fEY��D*&�7�s�A�❼���/�V*z��Q�RE������4}��	F��D.� Y���A2(�`�&�Gǋ�R����W���]J��/}��o�9)7-�$����+2tt5ι���F\_�N!�����$UaA��A�֣[-��҇US�8tY��4�g ���� onwl�.;w�g�S�6���C��3W_��Q�ΐ�Ȳ2v)��ؿ�x䜨$3�[�?b���˗�v�[O�X��#~��'����,V<,����k2c�a�<ԇ�@��S�߸?�S~��3u�*[��ƍ�(�б_e���J�O⶚qas�d�Ҙ(>(�SHImG�hf�͘2P�E��1k��-�l���&8b��A�;n�S���G�w5��妬}6���ɬȢH�(B�Ҋ��D������|�寉�P�s�sɑ�GZM�j1�N��m5�(.�/�H��������� 䑃>u7��p��m)G��/��䡣D� b�j��żN�<if�g�3�!����{��Q|(@H'����]7�O��ꪩ�Z�դM�̩*�d63�q�����jN�����_��Uj�@X����$J`��/�@b�pBK�'�\ug�"�>�yh��eY���ȯθB7�M� ۂ�s� ��JݴG�E�t�Jx�*�����*$����M��Ad�S�0V�4��DE���,�Zʧ��t?Ձ'�V�V�.wi���f/6�����>�m���̋И��y�^=�tN�vp�Kia�^!d�ˇ��mSΐd��Zȕd�4XA���(R�`8��_�r�N_��؜�.���C�b�)I�.����$�A��Ӳ(�M3�?���}�p�}���b�G�
���T}H��!+�z�Y�U1�ee�����n��d2�7��(nH����0��=ě�����U��0&��3�\DجV�-�4�aԤ3��<5��8
^�����|w�����H�2n�o�IVk���N�E�Wq1��(�\�&�Ū�0

�f�֭�U3D)��!e��7�͘s2���S�6�;���E�������ص��t�Š�S*��}?�j[*ȇSfT��g}\^�~�i�8�-�u'r�ys��)Л+R���@���ݱ�C2������1u��C)��'����� ¬<Snn�vf��l�u,%
���'>���c�2ژ�z�PՎ7�p����q��տ��o�G�A����9�I����x$U�I�E����4'��DVfN��<)�d�9�����"/DO�x#*���nGL��}��讇k[J�*�4�!Th�X��Ll>�{F��h�M[���?$Fi���� N^��}�&��]ʢ�5@Yp��J��Y�A΢���w_���ū��I�h0��?~��F~��-%,��y��3zcM��9�c��f�xm��~z�1g������"T��q��U�a�3&������Aa�����*�6��~�a��������*+�|P���K1Co�)��(�X�]�V������̚��
GZ���b����p�Fr���/p�<s�O���<�a�Ӭ�����d�u�=�i�w���ۣoa�c;��#d���@�$��6Tj��`M�����~�@ƫ�<e��c�N�Q����C{a��4NEP�~�D�F��ہ3�#?W���]o���י��t-=v����y�n&yؤ����.�4-eȕ�.O�����{!JS�.wwU�+[���	%��臰h�H��;��Y50����m�E$���}IH{�ɂ�'�'��QQ��ᓨh�[mۚ���MK]F���'g�f=��r�U�q�&R�>*��pex
�>K]\/֍�    �I��E�X3{�7�t	H�0�O��ܼ����a[�Ōt�&���J�����a̙* �u�(��/�'��������}2��ո�K-&m	�63�E���L� ��,a�'W�،�YC�M*	T���@/6qqڝA�H��*IU��?O�H۟6�x���b�$
#3��.���T��-�����/[�G��G蛡R��5� O��$y�;�<�L6��T�F�mM�*�}؈#����w$yH�G�^�D�J]�l5���Q�63����H�䁘v#(��5)��d��˾�{�\G��N�e���^�a�_�)�4�I��-�.���⨳��7��1��mք-w y�F~���R��<��v�xwal�e8����	�A�ҍ�X-��ٚKr�>G�F���*��)�G�� �q�����2���,�1�+mv:6�Q���T\�;C�f�z��Dj���_v��m�ʕ"�d� �wPW%#�ldү�tu7��(��$-��"2!'����`�N0���������`5������`�&���(Ÿy� }.�ǋ�A�0/dO��C�I&$�\
X�:b{��8;9���O��g�ϣƙS0fe#ƪ��I���j)�wy�\RK���ihk>��A%�"
����vk�W�M�GTUy��@](y��P��E�@ʽ�\�{0�y�s��D^�>�QZCФQ�F���;�`��V
���
�����w\d�h�q������{_n���r/����@e�!Nc8�>:5����D�R��Gg���|�����$#n�jC���s�&3�Ce����$��Z��z��Ys�4�R����7<�x<a��y8@�=���k�ƴf�}M���}My_�λ�H��ٻX��($<�ū�4 HH��N��7`�^�Kw��NN�	-��V�r�ڙ\�ݛG]��Ь.�(*eJ�f�Z�o~���7X�#QZ�E��$S��m�?���`E'�4�Ѡ3-�1xtS��ͻß4i�yςN&�t��"t{p��K�r�8��P��K����4) �E�P!q)=���[��9G�3���#TD-_�!{��/��~�JkY�q���^?���T$�7�e"�RRi;���(U}��u���u��xz������b54�b�{��9�JYƙ���_~��@�kٟ��D;u�}[�+�U����l��15�8;��	�,_� }gq���p[�������ۣ�]����X�uM��=;Z�NTnѣ�]��w`!hV+�þ_&�Đ'���4an\�����J%hF��ٲ϶��/8��nO%:��
fgXV׿�&ʓD�~Y��������(�+0h�8#x�*��G�q��3�^ٛKS��-	��W��,Z���W�_d�����\5qf"�d�$�˴�i���T`t���N�n0�C���B�>QC<������f��jܭ�|qՔ���!��q$}GF������hН�Hr�"����2�r����;�D#��Ӗj#�&L�W7u�`&=��{���O� +�KgQ�J��#P+z--D���6O�O��
����
Fr<���ݨ��x�.5ݩ����O �������Y���.l�/�������(�g~�tڞ��˺���y�Sд�a��b��hY��@b��=��@���m����o�F���瘆������'���P�Pt5C~�~l1axC��v`���WDk��;�Z��#Z؟�E��{�D�Rd
׮�������Q*�����Q!e��z��}��߉zt����Ԏr�6�dӖ��@�%aҴ3�/����������
�o/�=�!�=�qpW�\J�4O"S�yԊ�wy����II�Et�&������o��f��9ƻ��;��5b��&�b��$���q��n.��C�+"�� ���h�t�L�{�]�C���q�����c�=s��QF��9dbϬ�gTϰ?����̼xa�<�}O=#��HJ�]���������W'�P��cj�,�:�4: ��9E�Y� 셒�����h�&.W�O/�,Ml|�k�fT�Y��:�ݼ�&P�f��h����0���c�Lk�{�M k��k�<ZO})�K�w��z|6`t�%`I����{�+2���_:�!���"N�pG�q+���gP�th�E�ob���y�Lņ1��Df*yJ�9��P�E���0`�C�;b�-�7��Z���a�$P6���c�t���։{^�b�զSR��0��f�`�D��Z����E��D�3��f��`�mTV�Y��zt��/T�Y���{���0o������-"����	���ѿ.8��Ӈ�F���u|$�4R������bZs��p��i��L	Du�p7V�6Y��)O�1ь��D�;�Y��+1>u��wO�U��͗�x�#*vnc�`���t�����W봗z$u^�e��F��$�<���S��]�Ǝ�@:�$�r��5o��b/��K��z�W�Ͷɋ��P�i;C���^�c'o��wc���&s��-i��a�6Dy��&/�W{�֊��3��^������m�}��_}�'��хZ����c 3B���3@�Ez1�/�@y:�F v����D�o�1����ժq�	�!V���ԹO����WQh���U�����~�F僊b�[Ү05���.�Iթ��?��DF�&��9��S�U�ڪ ���oލ���a+��g��K�wd�oީ�x98W�y�)+�1&tz=@��DNI2��N�.⃜�N��ǥX��?��f�k���Շ�֏nr�7�Nd�t��}js�4/_>`+�������ql�����Q3�Wc/D�!n�i�e���?@��l����
�hk#��	�,6��d;#��e���ű�<r��>(V�s���U�8�T	��"��7A �j?�z�y���Z����}F����lTM�撋�8�%�[_��ϒ��MR�3�G0����������@Z�"|���Š6i�v��
[Mƪ�[$���K�愲e:��pB�Z�\��Mҗׇ$*
�ki𻭓m���N7�}�(����L �D�E�{����ZË��qR�h;Fā�Ոr����i�fW#elL�"S�ja�:��
�&3b+of',����p�Q 9YL�Fh���g%�'��lQ��2���7>�#c��=q��5؎B裙���	�>4?&`m��]�w�!�n���������m����I�g/TB���|i���O��b����\�QZ�盚:���-���Ŏ��<�� E�<;��g��?|�GD���R�%�~0�ՂGtȜ�b����\Z'M5��#�F�~w��V��p�CQG���S&{ �0
��:6��Ȟ~���"ƝU��:��z�������7����}����B֖sV�0�d���R1E��D�F:`��+����^��x�k����nF	��[
(NwBj�Z}Eqhwl����k���t�{�B�
Y�$�-E�2
�ӾJg��ͤ*ZW���g]X��]z.4�5Ź���A���}Y�ٷ���m9��,�/��Uf���2
�=u#2�^�v�1��:�ټ��Ec��r�mp�{��{7��As�gq���&�������èA�z�Ƀ�h� �z�-�I�7�oǒ���ȝ�ޟ^�7��۝Xv�P@A$*��V��,&��%M�__�V��X�8�:����(�uL�����*�jԑ����+���1��j�����Y������N�K������pvc���k�Յ$�ʊz�K}Y^���!����9�,���8�����do�3p
�a��S&i�dz�6k�4E ���nϳ�λpF�B���ܶ��,��~��K���Ϊf�!�; ��"��L�z`���@Y٧��S�8��B���^I�`�^C�5���.\���z�|K;�*���z�m_�2x+㳽�0���j���	���#k�MpS��z���n�E�ڬ.�f�����C��z���G'�UQ�F[%��j֬0D�Xe(�T*�y9`m�\�G��p/�/�    �g�YӶs�cg��`�������� �\��5��.N�'��BUQ2Q���1�m^���*�-�DČ6�h���,��#��a��O3lދ"��-���!7��;U�&�X�ݔ��".*e�?��3��~ِ�"��<NM2���/���$����$Y�tgϷ  ��h�Ԓ)��6-|�dčmB����r��<M���z!�B�J�jҀ�>W�S�l����}��K��qW�'�|�9�+\U���+�y�	�E<�Ԁ3*�����AY������o����D�{�Ԯ	=U�xu���m��_�D�J'YC��:x'1�UG�Aq�ʍ^!������P�jD$@e~C#M�+[���-E������O?��i���F����`��Л�3�!f��m�s[�F3��Idk6)AL�&�U����0+����G�Uo�b�J:��5�T��
"�b���b����_�|�T��V�b3�<o����2��X�M�St�8���مl.@�hD�~8v��������~󯋮oc��ٴ�z9��$��^3�})'P'�u�p�DU�[�� ��NF1\X������9p�tBcjVk�<q��gฒ4�c^�2x��A��B����f
�R��9ƒ-$n:H)m%Z��֖������ʒD%�ᨷ>�qA��!%T0��a�U�W�_\m�0pk�bV�6,Z�=(��2���O�(����W�:�5imNI|?W�g���,8	�� d��C$'��ӕl+���j�����6-f�ӓ"Ld�jCM=�<|:���QN�Ixg�&�|�@[��a�'���:���,6�̻"��J�"��!��W;r�i�-R>'e'��Z��%VЊ�A�}V��g^0����W�2���d��h�}ј�J�ƩF4	>�:�^���8PG�Z��?ۛ��L����5�tM�����5s���-9OH�'\v|̗O�,¼�f��&Ee��5�`J�9?�#Jy4�"5������Éͱ3���ŉ���i���Â��s��.������	��Ƹ'�)�Ax�xuiez:�7t�����u����{���ʱ�5 �(��V��É��<��7h+�2m��!�0U�,��̃olQ��ǛJV)ɃN��]��k����s�!e�VkY�ىigd�4�b�"�_��M�H��|˩	S��7y߀��L���A`o$V�~��`�"bʀ�&���wy^�M;�L���[]b1"�Y�2�N�牮:�ټB%y��̝����s!	j�N�G����)����d�=�f�#Lc��;ã:H�>���9ۥ�@K��"�"�����A�9�y:c����	��w�Y��w�(����O�U0����v,�2
�BxĄ����0�>&.S�V?�#,��*���[�o��,/��H9=�?���?�A�I��i��s����b�"���uA�8Oۿ�	ރ���?*.��.� ���Om������g�-�±��� �8�<E՛��+a���+~����,�|lM���rg��8h�y�N����W��Er�M���p�����A�y���8�Est5
�E!j{�J�v����%�����(�r��z�6FDƏr�8M"Н��N���������G|��Ok��e��"���5ɒP��(�(��� ��X	a����3m(݂߁�r�Mg��o�s��G;��I噦�����E�ǋ�JEY���V)M��h�E�����
���n�u�65�d9N�6�"�6��J`Q�bxy�ڧm����J|����Ť�
�6�R3��,�Pƾ�䦫G��{'^z�ab���X�YJ >T4��R�5�R�j�:�g2��z"��)J�4�A=J�(-�(�[C�����������?�u�8��_i�x��`�^�e�Mv�Rw�|��&�Ŵ)�zNLM��96��m{Ĥ��~���?v��Ե�(�@�:��)_�>���-J�Q�G�QFt5ٓ��~XBΈhQ�Q����֖-"�!B d伲)�QF���U(�U��e�M�t~��p�KA튮������Y����T:z��
fU"�L�N��["4ڑ�/ NZ��%/b~�����`�e������:������,?��s�I��}*U/������9���9�X��}���i�\sT����]��`@����hf/��6�2����%�u6`*�
J�M�z��1�3��u(���\�4W�n��r �2.���:箘4���	�	�2*3����C(�����3�,�.wn�~f�žҞ	C�zM�b��e���pF��j���Չn�Z��Z�=P�i=�:���$����ƈ�2/_ޤL�|F��ٗ#��G�;�r�v>K.>~,���$}z���������Y�S7�8[�ؘ��壪�����b��a����h2c)�KU��k�k�+BH�B26�=K��M�r��r�~cf���`���8�q�%3Ma������%�tl������S�f���´�zi������eE�h����� 8���m�Cpڞ/��9�X�z�@3r��I�5\ 6أ9W���u^��kIE;3��9�-��)묯��耉�j�g�y�^-�#��e*?�h'Vdæ���m~2�P:m)~���`�A�l�T�3��,w{��+�d*��S�Qʩ�Rk���,����b�e�E3����C76����	y��aw´��WT�cPVk����>.��������g�=��1x,�+�։)�4a��������"�C<�0�g�3S�B��k�������'�B�kH�r�*�(|��py��� 9*Q�u���&������öw����Tc��;�YY��ǶL��Uky�VSj�uE��֑@ZX`?����Wp՛ mqv�%�����i-�}�m�
��w&ް���H}?!U;*�����w���_�^>ф]�\?���Dub�0�}�0�{d!+����4�ψ���Zc+7������y�
��_�?��a;f����(	̮�� ���Ǆ�\8t���<���}�Q�a�� O�t�˩c1AE`��2�
�_C[w)@����#�nU�]+�����b�=a�9ʋ��A˘ �ܲy�ڵ�H�c&D-���Ѓ���4�?��� ���x5ϋ�Н&j���-@�R�m�g�3�+�}O|�;��߹��&"@|0*��.�z�t���GKG�TR� �nxV3����Zd�i⺪���QZ�&1`�r4GE��kE�Tv�nC`�F�w��E2���/��BK�TI|}��Q�=V�����Mӑ�L�����������l�4.�Hsj�_8@�q�/�x��x�@�uJtb{.����-)D��դ`��3�l�8R6��{���� �=���N�D����5|z�����d�;YU�N?�.��;?�z�c)���SS�xߒ2q�$�N�y�VE��E���?�b���OG���g7��T�v]�^Y�&&W�`R����r���\d��Wo��w8�	Oށ1PcUt��g�����"�A�S�3E�����5s��$�����^��S?Mv�s�LP�`�ْ)�"�q3�,t����m�<�����-�0������e���3��r���؆И:�g�<,B�i8@���k;�e�"Kg�֞<�+�iqdl�NQ)�
�-�f������R��N�(�D\-�)�?��S���n_�l*����K��B��Y�E7O~�r�ˈp�~��J��ĠL]�xFt�8q��4>O%5� $��0ҷb�������s��?�j��b�n�ɒk��(L���4	�G.�;"����-�KF^�Aվm�#�?U��L�ƫ�n��S/�޵I�Z���"iܺ��A�>&��e������G�Ɣ�D�g��@�9M�ѻ����E�B����z�>3��XF��G/C�� DG�x�@���~hPH6�E���H�.'rѡ��&�-���潈�R���E���"��mH�A�G�jP7�I�[
�wU���ʄ���@g��0�뺽|C�M}[y�W/3]X��K��S�ޒ���@Xv%.�:��xo�c����
���f�%�&-rm�������(��Y�a�̅�ͫ�/�čPe��T��<��    eB��mx}b,�0vy��V�*%B�0��?��~U���l�z+��ʟ��Q��,�
M>C^����2x��W��A��~��vw��6�{�����~l[�X͞e��UE��V�;��T}@��B�Z_�d"*Z��;��5 <$cU�|�*.��#��,܀2�W�;��+�"B����k�Gl�h������("S9�n��/�d1I��9ʉE����m�D��^��=`�F�7.	�J��ۺa�_��d��it}�P$�q(�,^a5����%'&d���|�[�S���?�Z$�Qm><�c9�j�0����$���Kښ�>=�Y��s�~Y�����r�5��EثB����&�����=>vA{7������� j��n�:�����/�6/xy�,U�L�;_������f��^����	 7�ºѕo�9y��s����XIc&9@�^K׭Ό�'|5
�bz�U́ti��N4K'�p�������<
�JY������%�nT�lѤ���1~�и�0���"��T3pf�S�	�}ϛPڿ>so��EY���6c=�-��h~고��G�ʒ��M�E���NI�'�CbfY�u�;ۈu�`a��h�-"c� �ZUM��(��$��%^c�62�����a5$je3|�L��՜����q�V8��%9�g���u���#�{K9'��DD� �u���rǧ-���UȄ�֝6G�s��Y��m������Y�����iö���r(ߪ�S3'le��z*3�;���Y�B-�^�����6X�?PC%��h�ߥ��X��X��}�����EXh���W(�aO�e���}���CK�[���u����ـ��]�͏ݓ_�j���Քz[��Q�����k	�
E�]>�(�> ��6xҾN�:��$��Gq��*
E8?��'��qvחe��5���JF"K�m�GL�!�B�eu�d]�ru���wn^)2H������#.	7�փu-v�(���+�4v}B����W����L޸Q8O�!�{2mCe_J�W?���R�[����r�_��f�,L�%I��Z�"�	 �8i�Ey�����}�c�u�F���N*����+�iKl��Cgc���@-�91�~��-/)�pQ��&V'�Y��6�*��QP> ��j�=Tm���l�!\�����N'���e����hu�?G�ni�O���Mߊ��������=W��I~���� �-}Ӟ�a�`�:�q�έF�+�y�7\�d����5}����mCz�y͝vn�o���d#�(�h��72肐s�#��j��#����b�im��6K���*�4s7��12QH`I�t]�J��3�.��!k!���(B�B�f����J�{�����!�]��!��ᖻ;���΁�%T�`RT��8٘J����Ŷ�u��3��ʲ0N54��TF��)��Z�`�CQ�[jp´{�}�ҭ��b�+��bE���'���n�fx�4�q��"^�V��l�ߝ�`�! _Ǭ'T�Xp�&̮�	���"R���C}N��ޫ������j������j��� �uo;�jF�L���"V����D�t�'�S�L��-L��d.��}h�"��Qc��H�EK��?�.���݊i;TP7��?]�$������z:]D�,#�6r��5���d�/:�"g� J�����F �ʐ�oS�U��O�н�ZUL��X�q�CH gD���K`W�DilѺ�ԕW�Q]{P���dc8��Y�r�4��AT�V�^�]&u�4����F��Vn�D5	��tX>.	��Pj'J�O�����@�Ay��4@���b��[ī���v�M��)�LF�n�4x#P.�G�r�l���f�?؊ڏc���&�u� N�]�v`�V��,�Z�8NfP�쓙-��,xK��t��iIy��N�ݒ1��@
S�-'	)�灕�(35�G/�3*X̾��m�=#)'Q�H�En�	��P0���q�^H�ދ�iWG?O�v���_]s9�/�@f/_�V��as��0V�@	!;�7޴E}� E��:W�Xr�;��f޲X�ߤU��Pǥ�`���Dlo$�<��G&;�?��;kI��Ԡx}�i<�8?�����ifıpb��	TuO�sDF������{��H�WqrN֚]�Q�֐i9f�gi8�˒(���[Brl�-��#C_�@|�0p;n�NR1�<����4��\-��������"Ջ\F�k�0�W�I�޽+Hl���屻;��{Gg�����_d�~�I�~��]S���>fy��Zܕq�z�kt��!�	ݰ�9�S���
�n�9��Lt;��k.��kݰ�y�_Nw�9�c��!�u�*��z|A�F��Q��;��u;�Y_>�?�Ζ	�A#D��ғ�D??���9�\��",6��ۿ� �\��δB!�E��}���@�����;,��>���G�H���x�|;7���\�y�v�-�Y�A_�ݴ��FSv��s6mᨥK���~�ۼR�Jh>jy�}Ρ�!�qxP�gu>�x���õZ���@Bc�|��)��I]�$�A��]�� �Oͫ;[H?M��E*r��p�8o�;�t��>��۬f"�4��L�̈iE��^f<��L91k���>����� �)�䑲�����6*�P�b�0)�R�'uqW�2]R�!�Jߝ��#Q�O��zk�S����#�t�;8��A�75�Aӕ��n�{���X;(ؘ��H�N`HD]5G��(2�z���P�	�����l���is�j�1={��6��w|��R�T��s�k�Z��xJW��Xn4��E4c�dJ�����(V("=��}=Pͥ���l'�_(�S�&ٶm�i�0�!�㕶v�H3q�������"4���L��Dd�_����L���7m�0�H�KdY�f��J���Nᣤ2T"���ퟝ�T�t3pe7�`YO�1����6�^<1Ll	�a3�G���=l����e���҅����׺��ZO�s�5I�]O������H�0�6@ѡ��NW�	(D��ʰq�u���#+�lz�R�e���v49��d%i���c���Y�z)O�?�1����8
ػ��%��B��)
�m8�G��ZE�Q-T�A�P�-����Ä��Ջ�f���ps}�0rn[&~!��7�%H�iW2�lo��qCV�mQ�􈫔 �z>;�}5�˗]o��-�룘���"�dRIc�0f>(��+R�3ƍ"�Sq���\�н��N$hqP��˵0f@��(���Ɍd��Y���I�ו{��H>���k',jm]O�O��"��m'�mV��EU�5��u,�L�r5K���m����PfqT( �d@��;������7�O��l��;�^9N�$�Q"G�(G6g����P��=�E��3�u�آGcW�ރ�xN7p7�#~��}�@p"���M������@m�錼�{�#S�C\��P�@Ts��I����4�l�y:7���7�͆g��W��7}���j���@�a~� H��A���M���(8���\�6�������H��	F}�qm����cˏ��0�o�L�ϐw���uT��J�j?�5�0��T����V��D0tlۼu���`�GQ���D�f�.��|dO]��N	�	~�AthbBm���q�:F8ұ��t=����䭩�f�],�Md�㝜���'Ftű2�D�i������*h�^�Ҧ�LTڪL�V�DĲTmt�0
���8���Q�rx���@p���9*�Z�L<���!AY78��N���o��Ā�a��x~WE�"�/��a����yql	� j�N9�+�\��c[�]%J|�D�.�$�Pq�����o���A�u� ���e6��W��t�6�|�/D�	�[4a�H;u��(nϤzK�!�4����j���re��ٌ*Ä�?mq�<�VNQT�$�����E�4�Hrv�'S8fp?p�ͽ�ҝ�N�`��6��j���޿&�o����<��,
�@M*N�n �e�(ֻZ,��n��R�灂�f�y    �M}�]�S�
����Z ��N��f�3����d��z�e���^H����l䁶Մ�E������1Ⱦ�[�������O�-���;�������ҎB�\�y����^v���dW�.�����(��7��%�Ù��u6�e1\��>_hm!�$�d��yFڰ.�2���Y͓e1�����4,x��i�JeW������Y~���N�,V���Y��Fm� \�+��~,O�'a<W[|.��mT�3�Y���g|q�=�o����̉9C i�p'?qw�B��v����V�"/����ȯ���(v��(�~�tV�9��B��|����>�I"��|	��/�nN��RM����mF�`��>��@2�j��X�]�fŌP�I���RB�F6���7]�N��u`����[�!}�j7R�W�V(.���EQZ�3�W��k�l{�=������-@�,��U@c��a4�+?2y���Fc���4���Bj�	������"�����rz�]ԥ���pQ�F���#�����9A��� b��][��/�z��М� �2��o��Ձ��6m7#���rA�����o}bq��Z���+-L&���aܚ<r������r*�DD�]��l�y�;��V)��d���s�!�u�)v@Y'Ol�_q�v\R���x�(��0���F[$�&�G��I"dQL/wj��cxБ��������>�ª�qG]���Bbc� |r���	�E����"O����!sr�U��W`�1�R��]R��(E��Cj�{ :8V�#�<'P�+q�۞&�_�޶>�W2�b��<q䈌ZJ�-��/�ޥYϸ�Z�DI0��� ��tN�Nn'����}tqW��V�4X��eqS�	U���(�P��=���h���;�d���u%'��aO���j�N��c��o��w�Q�:׏�,x]����42��
��N�q_ LrP}�Nv�[�$X��3��zr&�=1�T©��O��h�t]���͛z�#�ag��̓������ў�HЩ�03� dA~&N	�J�8a��f����ӥ\�
�+L]θ�E������A���7x�tZ>���"s�z��I�;���i�.��ʼ��ނ꽒����=)t�{�d��jl����\҅-s�ٝ��E��_�
��Le���c('Ϙ}?����d�Lj��#\�a��vd�y'�!����}��5���.k��.�ݞ�|��,D`9N�Vrb�k�wU��3�òH�^�8�P��
�t�c�� ��U٫Q�IQ���/`�F	Q��\�dM��?�YeL��'owUכcX��j�n_�ජE�sF���5ԴT;�����E���:��>��Ɩ+��Og�����,��=�{,술�É��d�,m�E(Z�Vr1�Vהmv����4KcP��B��
|��c���̾��B���Xo��*�QM-W�y��L��M���f��I�enf[�u3#��tr������ظ�K���6y�(`C�$�,J*������ ?�z�K�r�.���[�*�Y����&Ӧ�>Ūr��n� �WK;AI8C�0Qr t��w�!GL��չ�J����ż�|GcLT[��y�lb�ڝhs��Fg�Jw&oW1����1�R���I�'< �+����g�o�&�{�n�ĩ���ZG�$���Tf{~>ܢv�G�S,a�Kţ���u05��P�'����fc.�U���f��9S@'a�;��n������B2�o�+$�<�����V�M�)� T<;u;V'�OXC��j����)p��W�*r��r���c��@�����z���!:^�&l�ɜ�^j�)Q�f�Ϋ�x`����O��F0���e�����U*^�vg�j/0�Y��'Emy�s|�\�#���{�E�.2^�ð�g��8O���b��w����#,� ���G�Z�(y�}����1�s�Zg�����\�g�IT��(VdO���gE���8�#�cq���E���-�R��XM�--��_��o袪�焮3�nM��ꌎ�(�Ek�v��������r�W<ʗQ���
��S�i��z%�0��ri��K^��.���ȯN�C���2A��(�8�h�)��eF�xP�?�� ��w�o/��=�l�`�w��T�O���Y�0�h��T�?�C��Bx�a��@idQuE� TXE�{b)o�F^XQ*�m"�������j����*�[�4�?�-�<�DlC�J|n
��9Br�(�c�|��Rj�� G�'�kFހ��;�IZ�3�KZ�n�D�-���}� ?�U�+�	Ϊ=$"܊C��q/b�������z��m!�7�:�aK�K<i�e3^�,�]�N������<��2�	Ҝ˓N	(nƊ*�b-����V�����/��jV��N��$��x�����|=���)��É��T5�k���r:�}�3���,�b��$i�{�n�t�ZU�3�.����������B�si> ƣ�������hY�o����b��}^�ٌ�a�h͓d�v�^�U�f��yʏ8�l��=�l(��U���J�k����g�(�zF{[dY➽<x��0Nȑ��SM<�՚����2��'�qE�=nE���Ξ.R��#l�h�8������
r ���
TJm�ᗿ��M�i��"t��D�ˑ��I�{E��O�:՜,ӄ���7�p<p(�?\3�4B����}�s
w�ˑ�7�'Q��72���
�xU�vZ���-�N{���XW��d����8߰���'��v(�m +!!9��"�/xw�@Q �:��]Z�������LmDi��-�{����%���#��\�6����X,'�zЙ��}53d{b{�[b��\����H�|�q�F�G
2�0`(*0P�j����j����	La\���G��%��Bo���t�,��O���.#d^>���������I���(%+v��N�/�	l�-,V�6��`��\h��w�nt�P������}*�jF�L��uQ�Խ�rG�-��_ �yx� J�G�xV��L/1%���t��_}���GP���eX��E]-B ��������+�'��B3�S�#��R��=�O��k�D_��:=�����qHJ�wu�@��(�)LnT��?��\NW������<t���!�x�/�v���Q�< +S������aD �֠�8�g&1�.ӏ�e��b��
��|�Z/����:���l��(����x�U��z�(q��Hs,��{�N�Υ���GE�/���؀�c��pQn�e�®���g/I��jp�I@��ꚡ�Qgےi�)�m����Κ��x����d�iU�G�W �Dhi:5��$��Ηq�&�CcIPF3 ���&��t=��C����.7��&�fN⚄J��4C�Fe��G��h���Lbh��Ǳo!�G��8R�U��z&�i'K�\�����\�D��R��L��=2�} F�w���e�	��)&�����+w�&</�a��#~]0]4�,&E�Y,�/�]��Z4m���I76���-ɈL��m�3��݇�M��bmj�t�ՔY�-¨�g�4IR�m|%lH@�ú0?�����Y��?�S�6`X��.Bם43nqZE6�J+Q��.��� �W��j_}�18���/�*¤j�eI�������6�ss�ѳ�UW.��@�N��H��&��p��g�����<w��\m��X�W�i���c��<,C��(x#�3��>l���� 	�*��I�l�]̕6�Z�^�=a͉p^!�t�*���j�å\�0��pF1��yl��;=�k��NTң��5�?n��̭		��ʄ���3��V[U.wB�sB�d��I��A��Ӹ<_֜�bB�e��qHɜ-�����F_�=�E�̉��չ�4���8q�"ȡ8,�<0�j�t)dn�y7���yjT��5
^6?���F���=�Vte�ưBtt����aU�����Js�>��U�j�A�dJ���D����ěE��P�����_�Տ��Z�ŀiE�*����i��O    eE@�U��h�٢��x�|�ٷ�D��=5����y��ٖ#�:zNłS)���&��x�۸
oo�RL�-�� <�W��?���&�ꁼ�Dv�+�wE��º;�'C~>��"���ޚh)bQvy7cM�FUf\��
��|p�J���ڈq�K,�yG��o%���%?�'��� �p�i�c�|�,�"�p;#�q�0(g��id?w��2ߓ9��L���Zu1ݍ"���$�&YR�!ˣ���.���7�p�D��b1�ظ��e��&�y�0���\ʢ�pϔ�0o�Z�%v5s�3����'n��6�78V;�w]�{=�B5�9!jP%l�CQ��}"�����N����ҽm��%���v/���$Zz ���3=�.�a�q�n.IL��a2CU��<^4�W#y,6T��2��wq�d)�%O��@Gu�]���;����S3�t�1x�'��$73j�5˽��漢�`�F	̳�%S�7�)#�]E������w��4ep��X��B�d�������ԗ���dM1�vEn
�9z��#&"P�Pؒ�O�b<<�bO�!G-�i�9,3����đ���)Q�T�Y&f��E ꁢ�e�ޅ��*	�����?��0��� �6��y׺�����Dҁ�Uc���J��X�m,]V�S/�����vy�;^��&���̫���a��}�ږ�癘���;�����L�<2,V*�wuJ�$�#ڳ��Ŵ�9������r5��b{ȨN���eaژ�Y:>]OO�y�T҅拮k�!����#㴚 �b�G �0���,�}+��w�S���g�[�2Ш�(�0b��A���������-�W�TDmR��\-�=,�೼D�8"'��O`� �/dMC��'�&Z/6K��.�f,��8��I���t;�Tj�)\���]|���	@6 ��^���DD��?������Jw2��zS�����f�$���Z�i@�C�"T[A屠CyL[<spy{�K���(�Ǟ��j���T%�h[E3����)��e�dn�J7�����z�n��V2��"MZi�\/dt���P�`��U����s�\���-ֵ�a�����f)V����NJ�x���̅���J9���*��V[�.%�W�.��`�eYT��,��a�g��qZ|OsuT�/��xzz1�ۋ��|5|h��.z��噑c��(��+@����D�L��ϜסR��d��
CS��>��B~|1�ȥ��K(��u��~)��n�[x{z�ǉ���;�{�b�JJC��}�q��T"�>����>~y�mE=l�J"А#ݳF���x~��I��=pfr�7-�=(���qj�3=�s&ũ�W�?��w��߳ 4�f��LFϜ/���~T`�Z�桷#�p�I��8�yQ�ڽ�@��׊�cʵ���8��dFYRda��\e([[w�1 � �<�*���GO�3��!���j�f1�f��eu��#+#��Q����7���e����\_t�$�
\�:r�eÍh����t2�z���]>�����Z����b�q��3@cYYv#�8�Wg3�fQ4��1/�/��U��THV�I�z:_��h�8C�yh2	�blfh���S�(�l>��hd�T�QQb��� ��u���n9P�D�i��;.�~+��|��2AD�h%ã�UA	@IA�O'Ì[��S��M���<�2�����6,y��+7@:�]svQ.� �b�hS�2]��]lzwM���Q�I䂭A˃_���FQC^D+E�J�%���K9q��3�g�����V-������	����0�Ѧ潯I�>�w,��K��BJA��\&NV�	���_?%v:���IlǮމ ��l���=2 m�U�S�xS�1�x�&mE��S��i�7����eZ$��/��ӻ�6�C9��u��zl��C#:R@��X����(d�(E�k��H�wO���uE'J��3`,c�|�hmh��TZig|�ܳ?���s�����"�If��-��`����@9�>�N5V���	���]��v]���U�V����~F�1�N��6��P�w@��.��8PI\Ӡ.��LOC�&Q��:�Ye��*�BE��ྦbQF�s�J���#NC��`�0�'���T���Ǻ�9�]�Q芦��0]��M#���CtNk毘��1����$eU�(5r�ݵ>�����T/�y��(�R��C�L0�A�VcX/6�m�"�Y6?���<�%1&q�d�O�X9Ӳ�8���EF83�a�&�[�>�q$��j���|��ͪoSQ�F��@��ߵI�葄n����< I����jk�^�詤8������N�mU��\l����Έi�Ws�Ҁ����	صn�����&%- $x��cX����IW�e����WYl
U�_0�VBfwA }_���ˡ������G�b�?X�%���4���1����jw����в�g`Y���<Z�Vy`�c�T�T��;�v�W��͕�pT3�j=��R~�ER]�VQ����O�ˏ�**t�I�!�;]�\	��jw��^
4h�m~� 'N��"&�&8;�U1��zw}���Y2qSDIj�WU��X�IBC��E*�I��j���&kI�dݜXT�%QU��t�z��57ȶg��d��������}<���ez:�=AJ�j�e��6����oE�EJ���?~�e�k�7H�JYk6y�e��.삹�'�$v��^"U�� sv��"����^����?΢��rR�:d�N�^B�e���9�R
�c��
p�cё4�f� T�nϱ
o�'NԣZK�ݡ������Qd�9�81J�Ïŉ6_�'��,�ҋ�&$�D!�u��/g'P2m����3~5Y�_�|�R�t��جX1��=�0�^爧v��v1nI�Ea~{)X$����a�i[��5� P��q��U�0��_�F �P0a���
-D�^����=��������27=����y���ʟ?�*����V�h��˪� �u2k�ی[Þ��vR=�����=�K�s�<����y�䵁��ߘ**��O��{|�׬k�6?�B�(p~9�(�Ex�T�%�Qv��������^���"1dU{�����d���#����0*���:�Q&��7"��훱����V��ל�x�_�hy��m͸�i\h��I�	(z�<��uY �	)�A6�i�7��ʩ5U�|���6z��I��� QM^o&=�e�*��""iyg΢��J��\dNaK�@߫N9�x)μ�r!Ϗ;��>@*��
ҽ��ӣ��(>�NL�Z�/�u���{	��%�V�g���t����Р�t~4ȇ��NK���?�ƫ5}�%�m]�XAi�v
Ӊ��gѝ����;q��1tÉ.u?J��*�;��Gnd�$4��(�o�(��*y1`c�� gi���ܫ��W�x�U8d�YVb$���6������q�&`\I�WH�E��G����RI��?(��H�۲I=�0\륩���a�����{���NvN�O�u8{S���q�����tue�S�֐\6�� �+����N�	,�Fß� �Oݚ�'�i�3��P�{H�{��Y�!����QV[�O�"°�R���5~/�/�W�t5:�b�A�ќ��U�O�y�^J>�[L�/ ��^��њ�3~p/�9,h	/�6�.[(�T���I^Ϩ�,�E]�+��Jc�Y�_g�Q{[:������ieٌ�U�Ea'���߭*�<�$�sN+�1w/��>�/��<mTw���sQ�q�,�8���f1-�4��V�F�����M�<�TNW֭�ʣ2H$�l���c����^g���>cDW[�/'�fa�>*\�/5gGa��T
~�T����k��.R2���q��J����cϩ�e8
�\�y���[��ج�cx_�UhOA_�]��4W�Y��#w�?t��?���0K)�y�d�ﺊ*+T�+� ��憏/0g��ݩ܉{�{;�=���/����+�    G��]�W�h��H���n�̔��u��.	~C�+ݤ%��*;��iB[���J>0F�C �9dū���d�Ҳ��zF��JI~q�R����'� ��'zvr����3�4:HL�q��,���U���}e�%�,�I�Z:�����4�"W���O?��"Q�ț+$�cg����{��Ŵ��`�2��Ğ�<s(�{�M�(�� FA)�X�f�
9<]Y2~������*��g�����k���FYۚ6�v{{�S����7�~�;��E�����l��% 9��~8��G �$'�����%.�j���}�#`���Ԫ�rZo�\�'��#3S�
��ri�[��3Β4<t�b5(�r-`��xF��<�CW��C_b�
C�wJm4�@8��t��6�݋����j+���e����̒b}�8>1q�&�S�+��N,�h��Y��7�׽d���m�Cn�۲-n�)�,�c�q���`֩[�y���)�AB��Ko�>���ӳx�\c����qg9�ޭ��jx���,��|F=���5mq<:�^z%�s�$��d݋u�Sv0]�ܚ��jD��ʕ,�l�ҽF6D����Q��y�k�f(3��YO3s1�,�����U#�S���%zy��G����^�eGM�����8��JH�y\C�m��~s|�5o�C���/G��4on�:�e��3>�r橆��$�
��L)�qIW�;[ʷ�Ȳl﹬���C�oU�F{�����j�:�
���ֿ���Q��T��<�Y��֮�͊��R�ifO||6�t�A&x�{r0a+o����?�-8D�۶�X��-f��i2����8�2�~�L��C��6���Hy�]�+�^;��L,Y������H���++�X͑~1!��j�bSUF�=lU�g��(��L���C3�����������~�k֤�zDWU�/^*�j�=�Y|2��x���S�l$f>���U�^'��*Fֺ����*�'�i9�Q�W
�c,WS����^���9�C��W��x��;�^q���M%g�1�� du�w����[~��*�S�EFz5��r%m���H�����I�6� �g.b���Ϣӳ��y�`Q ����8ĉ���b� 
�7g?l:�k�hތ�j�]�9�6*g�TYj"q�o�8VL�3�l} w�"p��x�<У������L*�M�jt��oy��p.��ζ�v��M��Q�E_�_`�Q?�륵��"I���P�:�Tޥ>*]�Ze!~y��X�)��.v�aDW�[.�y��3��U�e�E4�<B��T=�����=i�;ſM%6�X�G�ڦl�}m�Q6��+B׬i���0��`�1s�8`[C�c��rc�<.®��<�EWR�B�{?j�	[uB��O�m~�1�bu��cEi/a]/
�:PO�d�������O���53�t�$��<U�wLI�|_�u�x��͖����l�����~@ϫ��N��2�?�e:�?Ni�����O�1�}uq/��P���09&�0��}�/���:�`����5k2�8�`{x�����fo���L�ˍ�������  a� ˟	���эSN���.��.[���!0��_-�.����y2C�*�P���4�T�J�]��ʶ��Kj������EQ�eEnj�Z�����$9=���k�a�:Wߛ����QTd�c5�H{����&� ���v��_��h\�8����'5m4G
պ����-�8~��<Q�Q~�aP`��Һ�*E��x��'�i.¬
��^�D )l��_�ӳS�v���\��1c&P��?�`���)�3�X%����{�2w�v5�&/�e�A%q��~�,�����hpZ��a�g���;�)c�zx���d���zFj��R(����^�W�^$�|�\ˁ����J}����?T�L��2�oYkJ����7��rpB��ǳ����'�C��Ͽ���1Y�o���&B:�w5+�=�]��Y���r�&;A/��j j��
G��Vw���?_7�H��Ʈw�2YV���`�s�|��A��n%��#x!W̓����r��<��E����i�_�eyt�驔�&L�`��R�=�|������.��_D�ESU��Q��2���
R��՝����O����M\:�2�K;��3SH�sʣb�S�Dɭ~$29���=]����#�x��"�tϺϪԘ݌:$�kz���	�@�"���P?+�\���m��o����@s%�I�P�%� �e����&�o�	��o��H�"�\�qҥ̅Q���մ> ��/r"˲��ܶ�i|��32�G������dP��5ő�ѱ��b����^"�sm[4�2w�ʪjF.����i|%5��E��Ur(6�^L�����j:��R���.�{(ȻظC�Duq�A��f���-�Z�*�����j�"���#�S���ISw"���J$�eN��TE	M[ �$�>�z���WC�.�ț0�fd�$.�1N������I���+�o�4.�D�Lz<Ql"��]W�˟G���7T2�	*�3ī1�#��M�d3�D���
���=kb��ܥ�E�
�zh)�M�^X�w�lV0F,�gw�����Z�,y�B�7����r#�b�0�����h_a��Uf ��L�^�Ь ���2KgN������Δ�d]��a/
�3�SV��{d#�T�Ӣ��l���D��J~$��^�~C��uв����TK�8>jȱ$�3O��|����+��m|���;�iR�׀�σ�:��I���� �SNa;��Q*���$]ʾ�p7=~*�ǻ����yW%��8��nq��_���E-$�<�ޗ��eo^�\��G�kY�?�\�i0S�b��'����4M����(KK0��$�ux��< Lܣ��͵74*�)#���"·��2�~�3LȾR��@(2;���{)��4�Y�م5+�$x�?�FE���~�@i*Wϛ�1&�s}Ѱ�	��w�=��n�7~����.�Y#�+zg��<+mm���gS�z�FT'bo���;���2���ҘT�"�$�Yl�c3i��k���Rt�"ܶ���3�勳�d�Is~��34�($�!o_�ŢhS�K�zF*]���Ng��ψ�Kv ��K��6)i�+&��v��C��*��Qp��]�B��;����0�+a4�R�dP�'��g�$_�ݬƩL�B�Ьp9	Ϣ�^dF����֣DLA�(zAV�!Z�,o]��m�8�S] �s�����4�tTVIf��{9�2��2k��ϳ�4v�.�*�gT�UZ�W�x�5��֪(�Ձ����X�a�b�D�C�)�G崍����oPd�����O��Хc	h_��A��P}D��h���9��x�ꂀ6�UG�� �gi2��>�Cyn��A�~zK�'eR�oV�z^�(�
���`��̀w��꟢��#	h�Y�kEoB����?��@V���.[����$��,� �]r��\r
��04߿��|���8�*]���P�\�-�ጙz�)��I ��I�-߶�g��$����erdk5�6EF�m�,����`Չ�^�jb+���e3��5Qm��<u��.��� ,x��� �'Y���'M�����2��Dbh�hx�@��	}7؃a}��k_c|��±���q���pԃ��c��_d�j��<}��fE�w3���'M�"wM��Ͷ��c�Ǣ���6_�:��(�w��A�3K���[��kRЌf���c�nK:�1�[m�?`;qZ�M�a1	G����2l�����<�)��w&;�*Tm/Jv���7��S�
0�?�j���?���4^�czSs�1&�d�)Ϗ;NQ�����y�Wk���9��v'���0�U^���p@u��(O�ju;fK�%5�.�~���ep��@����,=�C�*,g��4�|ɼ~�[���q���*j�ٱ�hm� ó�{9C٢�jF*���zݼª�K-�E�䑌]����7A����$��py�ZS��    ��fN��eU�G��w��������=u�_F�u��,70=bΕ��20���h���7��]sȲi����w�Qş�=p�����
��Qþ�a������'�㧳��d1�}�u�����ՀE��W���5��l���$�8x�	P�����	?�ן�0��9����)���o�� �uQ�A����#��
 {���.4C����4(s��=��I�X�?[l�_�Vv/�j�V+wJd˻:š)�W��Q� ��+���8�lŹ�},�ͤK�e\E�7������,�G�3O�z<=�J.�;y��v�\�!M�0��՚�尋e�m��I����<�����/X}�_H�3y� �\F�,�+��l9�d�-�����Zz��뺓�\��O�r�K��DW�/��"��?�$���3�"h�W?�;����5�	����1�yhK�#�#�z��8�0�!^�����F��I{{�q�������;%��w���l=��MS�[w�\c��D$�z��ť�gL��tM�ƥ
�x��e�㼭iͨ�7W��d�tq�q�`^+�0��I�/>.�j;c�GIa��2��ea����)�oj�*s'f=�ŨkeQUM9#0U�����L�M`�䎊��:�mh��*��D�A��{�c�_��yY�Q{{q�UaT�2����e��k��9�)����q�,@�2Z�`��r�,N�`��J��?�=+�Q�J^���i��N��(���^FQ-Ѽ�z��b۲��l�8��T;�2��D';r%����'�5_M�c�W�\X��/�j;c�뮅AI���_,�̻���;dC]�lZ{�H-�@؝+j��a��׿ +�q��q��-u�_�C䞭���w\Ӹ�u���r=���H�U�$s^����Ť~�<��}0h��z��o�<7���ڿL$ߵz��e�8�g��\?���H����Fߵ��[�ec<��/tZ%]��~��0����U�P��H�&� ?�7%�4L'!*H�+Ws�v��v�;��]s�J�06zy_�T�|�q�.<�$]��i��h����o�+��6ÿ�)k�r���7}U�Z�ǪkUE�ϣ��e`��"遲��`
��3����$|�;F|��|1��tU��yW��ت8���2��� ������f �@���(��d�aE>=b������U�G/Y�Z�:Bw�nfRV��T�2g0�>1��
K �T�$��+b���[��Y0%6q6cU��e���K��:3hq�)R#���]�P���yT[�+y���U[���U|����U��nֿ�,�DK���-tݙ����� -�-ɫ>,����I^$��W�_�Q��>WPm�W����;����}��`���~��j[f�uD�~RV|���S^�D��φ\����
��q[�\M���<j���z��*�:
�z��+���/U)kp���sEiL���Dv�C�j��X�����Y����+<L����Oll`e��Պ�8+
�����|zQ㡆���1=��O��u�s�y'�
���ྦྷR۪��@�I0ש{^n/����4��w
�d�}��®qB�9S>�-v�J�1�y:2=�4���R-�_��j=1�Ŝ�,��pI���bn������\8u�k����t`���QcNÉAxb�E����\MZa��H��������I���I�LF/�������!]�+$����D��`�.�u���&q��]��15F��>r�5!���qS]/���m
�y��-�lX��%,z5x/�x���TK�uB50K�����/��?ZO��@!B?�f@��E�{#��/�t93�D@s��]A�7"�I�T��n���F��hĠ?�������CԄٖ�@16[0+�2W	�9a��[O�?o�(�*��k�4���nh::4��Q�j�_H!����t�^A0S�=�ǆ�=tS`]�!/���|�r��څq��5�I�k�@D���N �O$��^� p�Ms�r��?�X�z(��:���pF��
�4Ty���£|I�"�"e����Q��B4�����J��QU�����S2"e`���N�q}k����S
ÃL[\�!2/,�*{�\��_� 2·��G�����xU]�8��׿�e�?v�?J��W3�_�״��m=�~�<�ؖ�WEBjoS��xM�NX�:���ҷ��a?<�'�"��_|G�B���_�M\�n�9�}��qVYS_8�p.5�\�8��6�{U� ܱ�,a܇�nm��h�J�~�}.=n-�B���؆jV�<Y������X��Dy\܎�s)6�E�W���J�n$��O[�Se�C[}!F���B<����C���"s�a���u��6S�ۅ�'m2����8�tŁ
�n�|��3�b��z�<50�kX�y��e�:X�bM��b�G�Z-�X�$Q�ޞ%�0-t՘DIp�r�hƄ�(��d���k��J��A"��4<�jsvG]?�����V+a�$n�e���'�,
SE)�O �'W��&��n#)@m��|ە���']�WS�Xl�ݤm��g�'+���DY�EK;�]|F��nl�Mѡ1Ӫ��l]�Ūqw ��G�anw��zL��`'MV3²8�|�-��a�0	�\"y@T��o'Fv2  �@]|�����?KY��w>⨁�]Ol�0����m�V:L���^a���0��L�n�/@.�Q�;Ko�!����V��b+��H����&Kܿ�2�~R�=�i��$��\�}�g+|~�=mgqa��#U��@��)����"�IiT�������I�Mg�(��ǹ��0e�EmM֏z�j�Q"�Y���_��є۸�qY�Dш�o���M�,Ԕ5t��I�A��eӓfu Ѽ�X����.�w��'���H����z/F��AS�cA)�
b�9y'P��=���:���Ḩ������G��#�M���XU_��?:}��A�U#l���O�/�j��J�'��g��Q�x��9�6�x�?��GHĻ����&�,Ǐ<�ӝ��;�k%�� UM��'�2�z�(�x9O=M�W�h���*l���ˤ���R��._��8���(!]^��O�nꦏn_ d.��6�q|�@�͚_�l&�I�ƿ5ku�C�~�WW��x\��;����6�&rG�:Yp1��-�찛*jg��y���w'�e%�	���Md1JD�t��zަE�Hů�S�tYΈT���,x/��Ҟp�*b(��� �xZ7���rq�E}R<����]'��+D��v[f�8]/��Gӧ�FpV�Q�S��I�hs�2b�,N{e��ǻ�g���2+���)[�޺J�ٺ8�8weZ$V
$"�|��d�1�"��>��K�ɼ��NcM�!wޏ uҬ�]��B�H����u����|�^E���&����جZ���ŵ�?Q]e,��@�u��a֩jws��@G]+6f�}�-Ŏ/\��:ޕ;�ˋ)FR� Ͻ�co̝@=�D�@�&N��M>�o���	���t��<�Oh��.�O���F5-���8�v7.as��Ё�+j=�ؓ]'�<��jÎ�\��0��z���hWa\ؓZ����.&�?��{�S��JQ/�M�W`.�����&���\mq�\o�m�ω�{&쑨�߉�جI�ܢޫ��;AKX�
��E1t-���|��Cպ�}��X�{c���r��6��
,y*��8	�����<Ǹ�w���;k&��h�PN7�?N�Z��尷m�f9#nȠ���g!y�����B8�v��� �i�9���Y���Cx�`�6)�����ËIC��Xiٕ��������p�8�Y�/��%�'W��"d����r��3�����rƳ���8C�."6�2\��7���Z\�{h0	<4�q����A3���fL1ZC}�����Ә����!<&U{;����;k�%�p�WZ��`Rg������"L��~o oYވ�5	����o����
6�Xr��:B����8���r�    ��ls�c�im��R�$	)������M)�\<Q`�v����ӷ}MG�E��x5a�� �m���� ���Y���$~��uR6B��'[*J�e9���f{&(�Q�q�N��Ă\-��d5|�bh�6��n�t�ma�0Siz�p���P@�����|6]m:�6kKV[=.ǳm�p����I��((�Uh^v���+G���$r�l�^Хl>*�TCϏ/�ټ��W���*6e�� ~�{�[�����v��	*�Oz����Q�<�Z�ື�1�Y�%�=~^�M/L�D%�[�1"�U`\�0�4�ҟ�7H]�|v}�oǁ��	n�
hDbfj� ���p˶Z|c��D���qWQ��r.�TR�ト 
W�25|�tb~1�'յ��^�,�-�~��G��*$I����N�"���=d8U�ߚ����ƃ�6Q�B�`�ۜg����&�֡/���$�Aϳ��ߓ2�C�@�Rex������Q�5!)VC�Gm_.sؚ&��\�Q˵�N��̢�g&��O��#�ս\�ݥ&�ޤ��Q�搑+��T��s"W��0x{}qY���Z
�*�45��������u��Aǒ��而w��'P 3��"��\���Ol5��rc���cS��En�4
>SN��e���b��6c}𤠬7ޥ�;��E�6׳K�gj&�"\w�,W�,�񐺰h��`U��������>ө *wL�g�m��Fh��xȌZ\�@�\B�<�ׁ�#�·��^��_�2ya�m0����lD�����T�8��)�SS{��`�o�Ú�W=5z��^/Mވ�?R$ez�\���'��w�~���;U�6Ywd���k�-����6�VU����'E�iX9]��}�f�w�w�z<�rQ�Qݹp� *8� U�N��j��c��K�ܱ��&��T�e�jvO�����!Nv�F�޼�Oߔac�=�F"� ���@�G��&x��f���2��9=�:u=:T�|��n�X�_#) �Z��j�v�)M�C\.e�ӥ�9ؘ�=���L]����UƬ����u}����X#�߰M��"=w��Y3#B��V��$̓?zR��)�V�J!᱓c͹�!�zا+-�5=(��l��bp�H����\�qhxZ�w"i/�?�N�:��U�ܫ���=5<w����]�3�틴�m����8��{����T����(���G�y�*@E�CH���M�S/֗~4�aY��K�T<yO�f�U������ҕ�mw�ܬȒ8ұC
� 9Z�E�6L�F�KW�Q�]e�Q�J7;K#$�Nl9	f�-���RBJP�Q�h�a�u�y�XM��Z!'��-j',P��I
�:1]@���g/��oKh��iW���ve[�JP����Nd�doDd�U�}�����O�d�:p�r�`G���<���Q�k��&X~s��x���o�U]��(7��0�B��J�)5@L�@�0���%�m��������z���y�tuW3D�&*��dQp�5���ԁ����ʹ|���g�MR-���������<^�#Q�|_?�t�Q�UY���!e����ť�8s����̃/�0��`�Xu/�u���8_�!�'��ac��w[mL��Z����v�˃e�)9��2Џ҆���pm}�/^�D�)��_�k�8�Q�ajGŘԣ��R$�襘��fn��|"(L\ <A�I�l� �̯j�D���$A<OUak:3B�<����䨺�:M��j.�J'���7c���u�p���9���O���m�	QLp�� @�
�C���������Hz~t��o}�P��g�):�%}�Z�,����z�e������2��hya��X9���7)%8m�  ����`09����@ŕ� H>�+R��{[�4���E�Ys�*������L���ĥ�u>#��� E�ҭw^ZF��M��e�+,t��8}Y���uy7C�(]n|��r�L�Kv�"��Ε��݃k� ���z�g���P@&B����Z �&X��*���&�����e���*)t ���C�?kELX�jd6��¬>[m��4c����/����=�/���g�ڦk�UL�ͺ9�a�V���`ͱ��`��x�6� ��_�0��.�7�n��=�w	�j�|�Ir�a�΀ݖa��v"����7��j�D�N"������]t�A^%�غ������20��IE-Ƨ�p��~f��pee�NW��+qw$s����F�U�Z�`�S�_�;�H��4�,���|V{�&���gL��(J*�\�: I�O,�H�ܝl���#�~��ʪǱ}g���b�ua���ۢ�q�"�5vy�b�l�L��6a޴4O��'g�8�]Vځ�a��b�Z=L�o� �:�ͣ�+��Z�0��;�y�1���+��!YψK��|�����Z�!�-o1�D��H���\e�gi��^���X�I�����3�u׹<d�o���{����
sY�ǯz��Q5��I���5Q� �_��V�6/����;�tR@Hf⍱*5s(��9��̼�*��q��l?�����\�4�}_̸�)$f5� Z�N �N�]�^��r���`���i�Tơ�$Srү�ɋ���t5n�b&~=_��*���S @K�Љ�&rY4c ƙj�?��7��L�Ct(��Gf:��/��P����j����}Y���PfY��ļ>^D\��:����z��&�G����.CD�M��vZ�q hS>��S-��|��a1:O_U1�"ɣȄ���&Zg����*]�X»�?@1�yR� �o_{�j����\�x�//���O�������XR�"ߎ��2=#���`8�p��^dz�#������'h�Oj[D_.eO�lۏO�y���͇81���,�����TE�� ��<�8F��.B��7�x;��/h�ek/d6��Y�<;E Rbb�fr<x<8�Ҁ����]����n_�m9�m��2�L^��-�s#/$��$ڪ$���s�x�W�1,F9�$�gD�pU����5i�^�䚛��u�{*JQ|��*�GWrKŽ�y12Y�es;V�,#/E[D�?~P�8��5�Jx���J��DK�Y�0�� w�<�N\��1�%�� 2}�e3H$e����">Э���%�.b��rW��f�C��7H4_2e7S��W�Db��A����,8[٦�vFSU^��H�/<TҾ�lwu��D;�W?�d�Y+�B�"/������/�ԣ��jƦ�
�8����< � ��쏻S�|��Ir�/P��À��4p�^��Qow���È�C��v���q\ַ?�UT�9*���8Tt�"��u�`TIZ*#�\���������� C�?����0�{�(�]���+/���M�z��}�����e#��"����\@�>�(c�#`�L]\��\qܺ�ٵʔ*��,-�,��ۛ�*)��Zhˬp�V�=�*M .�mZ��w��>��@�Iw*��%L~��z:)خ�W�k]L�l�����*-\���,�{�����6��	eg0�Ղ�XNޖaZ�8XY�RPQ��������4�.C���Mn֒�OV�B[�$��
j7xT��&�jQ#�~@�3«m���*�VE<c�]�yj�#e�����`d�;?c/���#M��)����9�+W��ru��3nf�ezK���x�g���8U�p��dW}#S�H�_�qd�Q�Ԟ���U�e��Y�W���K��v�!��x/}��[�_���4���}��2�,E$�%�]���Ix=���dT�}�3nn����g�$x/G���$�mى�'��RVE|w1�f��Մ?�2��jl�eq��.J�<7�2�n��0s9�d��'[p����  ���cӽb�W�,U��a�Nur��ܖ�e|�Xz>\��u�c�f@x����
oº!������~����]���L�{��7	
v8J*�@]��U�{������;���'&3�@�Z��V-����!��{�E�Gde�
*)$��?r��d�O��������]	��
    B�:��L�u���7E̓�+�eJ[����?��i@�m�J��~��}����m\��|n`���(��2�r=�����;������:������x2��_����:�g��4OL��,�5�Iz��Cڿ"!���X*�nw�B��O��_�բ�O�����,{����{O
����p�+P�L���piK��ʰ̶7K����i�MDº��3.�ڄ�m~e݄���պ
>��j����eXUuR��"�KEUQ�s� �1�v��9��ʢ�����v����z�@6ay��]e6��@:P] 	t۽���Sc�Qվ��6��j�?��
s{��$���h=m�Ⅻ�I�o��>�3*�Q��?��Rb������*+��Vp=��X���WطÉs�î�!]k���;���ͤ��.
��T�,��;WhO����G�\[ܱ�NT��E��v}�v����;���zV��t�0m���8�w<~� �CN�����$1���#���k:��ߡ(N]���(��/ƭ�HY9���o�֍���
c���[��UF�{{n����*�jx��Y�����7ɾC�,Db�B&��{l>���!�bޡ�Ŗ��5��\�Qˋ�]�� �管0��-/R��+��Ӆ�ᚢj����ZX���ˏ� �
b|+���h,E���Q��g�bOb�d�_DNi3����K>c�1���q�UΌ��R��z���{�_ܓ�yθ���_�m(��z�*K	��Qeٌ�+�B�+U�w��bK,����":�:��'*�I�����nd)G:WA�y���d���hI%|D�lr8���� E��o.����([�o���k�u\�>:D��#����6�D�^w��~p6R<{m�N
�Я�Xʜ���yY"ϲ��x����Ʌݷ7��@�P�edV��,u+�*j�3NR���L#��W�9@��/w�F�zV��{S�$`Z:�ͯh���_W���1��g��<��&C7#��խi��u���L�IP��v ����M�1�RWg�fl�-N2y�ZHe�t]>���(�s��i�*�g�j ��7�
UH������{��8~��ö-g1y�2��0��J��*,1����"�����ø���g1m��N��w���q��^��a��}m�OPbH҅�"���*дc��z8nm�$���İ��'�>P�~ДI��E����?Cîn��J�,A"��ڌk��>�m�ΈSY�zgV��P�q1+� ��&e=N-v���F7���g/���~���}��7zh��|1�&��ު�KĬ
�KҥɲO�	�~��wC�5m�7��I�X�s{QC6��1��/>+��{\����
蒷���*�i��T�T�t���2��7�O255���:��R��،�7�q����1��� ����(t��œw4.�kh���~t�<���/7���~��(�Ӭ��kN�����c���8���cT�7&���(�c47�l5�ri��jƣ����,
>�\��V������{���x�&��2����*qdT��վI�[xE��_��ʸ��ӓNk`g��q���G��u��:� ��%��RW�-�� �������Nr0=��Wn��؃����( &@F�+� M;�0A���ԇ��y��w_���/�.�
ݿ��Sk���/t?$�2�z�'�,�����w�������N�zƑ�Jk��8�4t�w�d:�/w�W�/�_�IQ��7j�Bf�H��e�)�{�����Y+��b���=a���?!�Ӵ����s��O#������q��À�'�Յ9��4�>��1�Q���dc?��ù�^�b��8��b���\cWh8��^E&T�o�������^���׆�"�K�m���}��9�l63N^Vda��ʃ�G⮅g�D"ꑾU��:�P��l5Υ�u�8�� �8w-��"��f��إ��q0��̨���f\y��0�-���L��A����[��u�ދ����a�ܪ4���i�<����C��Ƨ�COUG������Q�q����D�w�÷�Lݣ��_����Y�Q�J�G&�m�?]D�WPɪ�K�7Je�ҩ��Մ7��4���.U�dͦ��|-ʊ��V�-.�M8�)ɫ��p��<F�D�'4�6x��*K�G�'�M��;��ځ��pP�henѐ�#�(�jI,�I0&�]�����o�ᦗ������"�p���u=#�ATR�a��L��>C��n�/�auRA^���(P��n v�\�&�\�xb�1hZ_L$�'�E���|PT��=b\xt�	|a�n���_�j�aT�pOK��w�kZ���\n�PV�q�<�E���-���h��y�s��p����WL<F�F���%2^����,���3�5������ ����w��2�bS)#�rj�����\b��j��>��H��|�:w�pF ��iG�{!�0����M@�0'���T�1�����H��s��*V�w�Z��iR�����f���Un~Q]~*m��h��b�|5�V_��";����bF����}I��
L
sQ����^\�&v}��g&�p�f���Ĵ����떄I��Ri�)���D�����eV�����'� y��3!�]�x����˙�K�(�,nU��q��zRW�`�q�&i;#�e�j:�����l�pp���*Cj��{���Bx"�0V�Q�׽t�<x�Ѧ� 2�/=Û�7\�t����)o�Ӊ��rm^�<��B)�"\��E1�V��r`/6��qk��C��
})��2��vN�*��O��tb��
�7�B�ڞ�E.����U�I����&��ŗ��j���ԡ�$tO��5^����,��~�����l�6��f@E�븹��b5���I:#�$QT؝�����R��Y�r��۵v��+������/��!�1.W��^J��L�M�a+b�M%a�wT���k�;>�u�qY�(�]g�?��1�n���aS<��n����t���5=J�F�3~�{��n����|���ہb�)����f�2��l�P��ߟ��P7�F��ߎ�4��������L;h�7����Ixs�
%Ƭ�sv�����ŵi��AD�9#���N�AGF,f�X|3�Kם{MyV�W/|���,noDw��0M\�V��qT��#!�h�z{/��'Xd*YX�����_ͤg�R;I�&�Q�e�c����Ҕs?���ϋ���IZ5݌��%&5�&�7Z�BR��B_�zTo��p\�%Q=��� %�"���oz��KdT�W/�^����d��U�x�$U���QΕ��������1� f��h��|��h5��ruK��Ɍ��i��4ɂ��bq�"��,c�����JM����Ӊ>�G�&F��Эֆ-x܊��焮*S�yp�c ��5����ͅr����h���/�u%E�T3��"��QH�@|he�"��Òƞ��/��5@�#�"7̈���L�m����gm���g����������R�K��]8v�OK�J2!C�@�m搀�\���,��0����Uh��
���S'�`�$:r�!�0òs1�.
O\!6'AVYU�!e�%)bH��lR���A{�Kt�K�T�&���R��Mt��I�z�i�nU۹v�}��������#�������d �{`J@��c�ת��#�']�Է뱤QN,���t���G�%�a����Xç�E6"�e�m��ҁ� �ʿ��|�O�/$�t=����%���g�(�Q宛�n�'��T��M/������_�r�l�f�#�ƅ�)5ip�°���B�|ZKL��� 6"��ՙ������`��������I|�C��t�a}ٙ���\]m<���l�>=\{K;�4��]�Y��ב��$LTr��PEͽ'g>j���;��i��c�/z�W�>�����<����O���r��^G@/B��i�h@o�ӊ8�z    �i�������ۼ@�1"=7fw��?ה�6YO%ʗ�ĦQ\淏�S�Zv�!���v���b��}�*�qKW%�L�7 <�g�����z�����90d�٥σ����}�*	��L�֓�Y���V�,�;�� �1�L�,4n@Z�u���!4wO/��`�7�F@*]_6�}E��ZOJ1HD���!�4����U�T�ȁV^ol������8������m|�{l�����I�$��u��֡
~�כ^-��^
����t��,�?q�-2�l���F�r�
j.6��
�'��[��,� ����,뗙��E��CӢ�2�ea��Kp�T�ƕ)b��]O᥍��Ք2��U�3�w���E�w�����('6r�@�%o�<ꦈA f X�L�@�Vk̖Cf��]�G.�����,~�R�^^'09[b� ������(���=,���T2��"|~5F�b��t����ؕ��dY�E��$�^6�ߩ���r��:�.��
ҙ .���E2h�ɷ��a�qM~���(�ն]0�"���mw���LDM�Z��u��8��u��	~h��\l)L��
3nD������v=J�~·9�3��Wp�Jz�}-r�-5	�[{:�����h7QS�&U�!�s��ӨV���1NC���NW�s.6��¦�g�n�z@�@�N��ɸd�<��J9g"�	�7Ȏ��X�i�S�ZJYq��I3C�.K�����))�ibMG�
�Ř��Z�V^�������k�z�Y��$j��u�4ux�X=���N[|Nܥ��b�� #������O����x�K��uT�탺���jӞf�F�/��[>�ڌ�uOs�GrC��7YEd�"���� �g��kY���o �y�p���pV[F�O 2��I�/S�=.�(�R0)J�'��Pd��hh3d��&C� R��
����E��z�������v����0C��������F}�X�'N)<d����u�/A�����Ox���#9��ﾓ?q~}~|q}��
�*#����l���b�ȩ �d�"V,"��.
�q�m��~x��硭Vc.Gq�/RfEU�@�f����G�?Iن%��O=�BA�G�(�n₇5�4lwt���,�������E��º�,�2-�C���u3�[&�f�<���������^���&ܤ��J~:��|K9��Y�F3 �Y���D��)ʜ��Ι��u�u���S�Y�z?�	�Մ��/�:�f�d��et�����1�Q9){Q��M����ކ��M���kle����du��L�AH{d�'�5b�73�y�(��Xs`!N�UaW��p,Ƭf�p$� !���WÍ-'��5M3�~"�*թB�o뎝��'P(���V�p���O�v�{t�����[L�"k�(���Σ��ιj`ᮦ�2+	��xAˋ����I�<]/6.	���j��֏YW����5��Ȟ�2x˲P@����*�S�| �\��v�6We}����rÅ���w�V���Tn8,��p�N9H���5�1-Dg�q�l���nϡW��7��Zy�帒Ej���wgZ�u`sݳ���&���rL��K)9��P�e�W��MR���s����[�3c@�rH.�:{	��E�쎲߼!f�|��2�$k����������\�%���e�v�3��8�m��W�!Ҋ�+��~�%� �V��C�̇Z���eZ���qw�=g�^����?ۺ~��W�ġ���Ex}ENh#�M������Oj[�.���>(o�=���'馦��g���؆�b���V�qK���.��-\���p0�d n3aEM���:J����5e��k�RE�D�-E�?���R���b�*�s�P��Q�Km��fȊ�i\��vZ��W���O$W���ɘWG.1�k%Ϥ�� I��Ax��,�xM����y(��FR]l]�GU��3��l�<�$НO�x=�#h֪>�ҌQ�Ѣ-J���q�_���!bBy�Y�����G#��qpA��8�xh��x�0u����	��H��dG[���j'E�6�^e:�:�v��ޣD���q����U��N��&v;U��]��s"��K�蒢e�T�V��3~����P��TqQ��UL��L�}UJ��#c)���)������ʹ���/ϳ�4��"�0�{ oe���#�0����]M
�*|����%�I�.&��'i��Q)e�)�Y���üq�QFH�Kw�)�#�a�|�E��m�	Z�Fq=#Ny�ٞ�ȃ�Ԧ�8��l�>rZF� 0��cPd����LD�w9���adÉ��Q|��]Jک{�\g��y�����c/X*���	��f�Kr,��U3���~��=P݉!�آ�Y��X<�	we�����e�A�t��� j��yߋ���"��		���x��l��}�=�]��M�ö����Qft]A6���ﺡ�F�9�Ƚ�TQ�7v�#���j��h��	18(�] ��T0U�a��U�y�RXd����E�d�T��y������B?���ipe�I�8~Y%K}���Z�~wO��P�򚺳�m���Xm�UV�WM4��`��_�*���vv[/�?�˲�S�f�&ܦ/�|6�	w? ��@z�Vw'�â\͒:)�n��[��f�4�ͮ��/
L�9t'�U�̷�b�Ze���r4�;��A]R�0~�W7��N N�zށ�ٸ�?���˫8�uW	2���d��� �p���SH���簚��r7���h��*Rk��8���j׉���@�@��T�뗳l�P93�����iU����]Y$5q�%�ge"^��V��a]�<�W�6���a�:A)��K�"E8aR'��n��{�]�&&��t�<��Io_�#�6�[�;��m��3"V��he����w��9I�����'%^��I�,�7U:�VDIYY`�����&��x�uN�*���"c��}r����]O���2�����9;�T;���咩�uaV����]L,%�ܷ�gD(+��X� �z1Q��6@yj�vK���3���A�NPS�x��(�/u�1�����"� �\7h&^~0����/�m��aٞv�'����wn���z�m���~�뺭X�\׽?x��@�\���0�Wڀ��� ��|l��r5���H���O�w6u��>�U�B�S�Ӊ���\�X*\���2B����aSTs"�jp����1	$.�C��|�% �o�q�0�;Fw�t�����F5��U��U��{3��N���j2��p�g�|ۋma�L�o{Zݞ���ȭ������}s�z��LLήJS��q� B��r�쇖3uǶ�Zm7�\y^$I1�
͓��B�J��2�'f�#f*���=W[���ѿl]���O�j���FE�3��Zذ�ʂ�0������z�6��@����M(KX�/X���%�ĝl��t�������p�C�{S8������DF�ĒRa6"S�6R�q�͏`=BbG˼YY���D,�0��ZRAՄt�� �G�Ad�tNe������2<1~�jÇ�E^�s�Tp'������ҞXm��޽��7ja�!�A�5�[*g	�qW�����C	_*�u�m�R�wE�ڒ�U%�!U��N&_��,(��G�q�XK����B�c����$6��k34�D=���T�r=��R�7(��3��*/���Я�#:Uhޟ��ۄ�,���k�W1�O��~2E(�ׂ�ævЌl��]	�yK��q/��L�X#���t�a��8r�z�2��?�&YY��'�e���}��Y��-u����+�U_���aQ�FƁ�� q�n�\�� J��@���3���?�Oe�}�b4Eݴ3RO%Q�h��ྦྷő{�vGJQ�l�V�}i�L\O�%"�"ʄ��/���~>h�TU>'de�۹J�? ����x.�4.���P{��E#�7���D�rm���/�4I,wd�go�)\�XRw���ݝFB)B^P�r�2
���U(�4/��*S�Uܳ$�����v���z`�{�    x%�K��Q6�_'�Y;r���Uq���O�GMw�n�L2���B ��2�(E.���N�|�>*VIN!��j��Ao���Q�g�Q�f��ծ�b����vH[��ya׺��	 ^����¶5W߁�7Ow��M����}g�V�F� �6���ʣآU���?ԧo=�^��"�0��:MWA����Qv��˨w�2wM͋8��Y2�X�\�U2'�d�HL�0x��$��""=����	���O�Q�	GL�Ǳ��j1tx�}<�fE�+�,�h�Kz#g8:s��{�=WH�3��e���Q�6Z~}�N��]��H�����|�U����P>f�s�σ ơ�ǠF�ɗI�532l�.��g:`��zJ=E��f���kF7兞�(�ڞ������ں�@���	28�G� ��j��a�ʤ�o[��b�������%ȷ�R�=e5�����jyt�ai�v�9�qQ���ȢlU	Q��<n�XySL�A�/��i�qx��W�塋<�G���Ք��](��kfĶ�mC��b��-
�pS gP�D:�z��O�E[b��oN)��n��c��Q�W��������E�A���3Ђ�t;��i�C��'H��%�j�~l��p zP�xFn�~b�η,\��Q!Wy[���p� &Օ�����ak��dc��"��yC6�q�z�`x2����h�v�ȘW��}�\�Il]FTo{�U����F�)(��7���ݡG�Z�N�ŒnF���>����E�.�d��%��*]$���3��Ϣep��Q�,xM�׏/k�w�8=QR��l�n�?�2
�K���m6�җ?R�x�ee	�"U��F�������Emu8��CL���A���]jS^�}6�0��*?���+���t�%(2+J�G�^���w�V�7P����j1a-�O��C�˦)��7���J�����/p���� �
%$̎1:�� =lP�N31��`���1,�+�2�θ�qU��4�/T����ޒ�y�Z���� �N�MY����;�0��B0��jܡ�h��3<�$�i�ř{��)�rP�~�r�^)�� �v��JB���o�p�g/ bF-]�Ը�����p���j,f1`RG]/U�Q���������_��&���;q�h��e�ߊ�܆���*͓�*�"��;+t��������j����t}��'���r�q�y��.&�"���4�_:��-�]�L2RЉV#by|���9>#O�&�����؉�i»��ѯxAས�b����'x�Q�H'�y�:�}���ڑ|ȧ~jf�����	^�B/������r7����W,o>�\�JV��s����d���Te���a�_�
CV�0l������>�aoV�� �ײ>��i8}sa���2ǀé�H�P�b�Fv1�@6Ռys�qjet��ǧ
�0˅���q�K�#�k6���R��I}<��W_6���_��ұ���q������8KuF����4�TJU���zw)~��Rm���HHS�s��׋���@"�'�Q�FxB�ڼ�8��a:�f2�p�sߚ��3��ޝE	k����%Ͼ�/�ƾ�����;N�uO�T�=
s��܉^�?:̼�0���������'�I���'�����q.^�䂷������K�Z��X��⬟�r���ym�Ň�Lu�s�g���,Ns�ŭ�e]:����<�����a���Z\�WIϐ*��$�u����l�Ͻe�uԮ݂�`�@r��,���v=�����6�Z�evuu��	^YZ˜�<Xn(X�<�*5' ����'����kH���'�BQ��vB��h��v��ϪLS+ȓ4��e���J��zE��͆5��'���>���n�}�]�$�畲D��֓�\j�Ue�v��X��"�$�������S�
r�ga��|���B��cd��4{J��b����=�%�GKѬT�*Mx��cbw�m�C�S7��@)�A���"�/�0��M��t^.:�����	[��$�X���	��,u��=<Ԗ�'�%oM+��Z�iԐE.�Ճ�F=�����Y��	�m�^��^��>��[�Z�Ҫ<��TZ��e��'
���]��]2cnQe���<�W�5��V6r�V�(�Up��S����dв�f����0*���a�V�B��9UWsw0 ocs/S	Q�5��-��x �|���b+&W���h�qhG�~a��a�~���C��D�^�|\ީi#����R`������=TQl�tYR�ޮ�(�K��慺�*�'t!������i�U�]:#4Ejh�0��a��0zY9�xw����#˟h���M��j5�rO{����{�E��T�O2�����4����E��6��)!�Ȭ�x=7�ZAϧ�5_�aX��,�jq�$��7�2�2��:^�)��BzC��j&*���ƥ����Kݛ��q$ۢ������G��N��ȖЀ^bʪlff�΁�꯿���y�蛁�8��D��*Kw�igIO/Bfs
�� �B�su�_��j�x��8��Юp8��0��(�k��-V:��F!t���:
���Pӻ�-8��F��c!�z8$�w��0��V��k��)*N�1{���c�&�O�=bd;һ����M��룙ib�?a�Q���pչ�����r=m�eٌ3�$I���4	��<6�:D�t=�m��<��؟E�^WFj5�hwQ�L}��ۛ[)W���$M�W&�K7hJ7��v��M�'�<w�=��_+���$���ָ����({��"Qm w�v0���E��!�5�R���5��`ޢ-4��ꥊ 7r@y�O�ԫ��w/��p��`
����;����?i�.fG~�N4U�aZ��'C7�M�7
�\�Ӵ�Q_�7�X��.�^/�e'�Σ��海����bN���q#���S�v�m�u���q�+�4o�6�k�]܂�ܥ�ҙ\�L� T>�.��ȴ���ΐ#�y_Mv���e����]���*k$R׫r.wR��C/��͛��]G�,��2,*D�����K���D������� {[X-@|�9U�fw�9ն.����fY*|!-����1��Y�h¥�8�'Rg�z�	�j4���/�U�E6� ��؋��G"�0_ӭ�V� �7u+ �t5����:Jo� G<���ִBe�,� fB�ߩ'�k$<��j���zuv��Z�p��VmY� 1�Ѵ4�<n|R�&�K���|c��j��d1�/T�q��ܿGY�A�~4k|�|����@�Q�\	
�qE�3&�{
�˴,��L;=<s��^� ��)̊��1=��f|6XgG��ث�0�=?�����<7�I|=��dm�lp�F!�E�ĳ�5�W��?	��^Y9��c��b:�LGԹ'LC���n׻��Vw_�܏�9���g��5me����w`dz!o���}��3$���& {�e���t����h�;vM��l~���(.SR�O�\�N�U��O�X���z���:�\��eN�V�e�9U��Cp��N����Oq�_M�%-�j�ii���fFC욼ܞ�̥����N�:l:,���w��g�HDX��l��T�IO���"��,�6�y��>#��n���礏`2#J������k�Z�c&�Y��\;N/�/4}7��䎉(�˩8 2��7� 9�]}���*4B��}�� �����c�5�%>�"��t�ar%�Ǔ0ݔ�o��b�8V��'KW+����E��nOUQ�f�l�ey  �a+�&�ϲ��$&�G������h�wJ{1b�d��K��Z9¢�F^�f�z����飚�Y��������x�����*�;w�`-��Y�~cj6���҂5��̕�(p���A��3����+̿�]��
��C̓��iw����s��k70�{�՚�
��F^U�D��x��3)[l�V�a�-g���2DPV��� zh���$c��z0�����+�	��=���Y}fB��Y+#�    �Uv.��V�]ԇ�G�Rmd�2��s;�z�w/5�[�]Sȴ��b���J�t�i]�Iy�� ���JY�=!�̯0�|)��~������&k��H��.���	���������yϔ)���r���R��&���g��Yy���R�6O`������w�W��R�\[�ً��&q =~�+vEQ4������{�����C�v�K����X�������3��� ߸��?���_��35����狀�����=�?>��8�v�p^�����l�g��{W]�)g�\Odl��\I;#k�YYj혇����húϵ�*�,5$�%wRk7ó���s��z�k5c�Iv1�B�$��(��L��y|����(�*�5�\�C��{ь��_Osg��X�i<#Jyf�y�}ִqtw�A�E��8������&�����{��nFTҨ��'�i�O���¿ǆ��:)C��#��n~my��uA~��wu�����/-2���i�;���G�c ��&�˩��}��ff#'5ς��!"����@ci}p� 
�^?�����a�V��\N���f�6��24rP�����
� �ڨ�k�9�����%�;�F�cp��O���S�9�5a�F�Ϗ�<IJ�gs�O�;���X�*�
}+�����0�^�����5��8RWsLw%u5ڝ>�g9��ˇQ5Q���eb�}�����ћ����� O���A� U1���~w@�zT�v����_Y��D�6�q��4�c^oG�)�E`Em�|��je��Eu�"�������U�7�pU��T���Ť=8�P�|�y��ݜ�O���o�(x;�mv�7���o���2����&Bx�h���%�I���|��pUah�]���T��QF
�����G���p�yS�Qʍ�z����6?L� ������FeZ�I��nΜ���܋$���}?G\O�{[y9yR���e���A�������R^lP(��j4��J�&���c��w�1M�1E'c�Y.QE����f�DC-'-y���&o�&��|<iY�ѕM�|'��8q���I,���A������㷝�����������x�{�R�Z#P�M[/�3���o�m�(*�c,��gLN��<R#��O�͇�����Rk��P��,7�iʼI��*<d�(����J��GӜx4%PH�Em��Ԁ!�Pт�$2��)*��j����*M��K�8N"�,@�z�O�"ɡ���j)P#�~��C�F�{t��8�	��|�c_~�!�	l9�NSG�x�y���`EP����]\�v ��ó�}e �h$<��c"*��㸞{�b+���&��eJ��ߢ-C
g2 0=THTA� %�N i���}�����]_|��-�2.+���B�%�'w�{��*���*��M9�c���83+s���;M[�Ō�-M+3�*��Õ�J,8Z3��rM�1�6B��v|}��Q�A�PIM�7�V2���/�i���n_���G��0��� uN(��` e9��^\UxG[O6Uh�0n�j��HM�}>#nY)�L��k�Gf�(p�G_�pܳ۞�ݕr��9�4�?�՘a�9b6۸)f+9��=�s���-(��ŴC����7�&]�F.�����!g�].�%Zȕy�Z�k"�g�O���ca��bN~���
�� ���D܄a_M��ɋ�\&�ۼ��"I
X��� F�1��MN(^��y�x��q�5�\���A����X���\
b/�l�6�f\^�[�-�7�ݿ;Y��}V�@g����� v�#�$�&Fftw~z/���3�\��K�И���y�]��?�BE%3v�J\�i�;w��܈����)ȸ�/߾�M�9��;z���� V"����z��"%H�mg��ɷ�L��x��*��j�ǂ/f�t�n�JK�VQ���ϣ��Ϗ�p��[�W�!�@0����DV�i T�j9�)�ed��,t����J�#i�\��GSѹ<2��p7��l	�d4�����f]ؕ3��Evx;����^	�α���9Jy�8ū��Ť$ۼ��۟�$
S�RX��_�&`z�q�y�y�U��yL��>���Hun�K�P
x�z4$���G���|�"�f��6,dքȨ�賱�\1끎k��2�����$�"�V��((M������� 	��@���˦P0�B�j��N����^yԺ��^�&IX�v!���H���w��	���t��V�h<}�4�gFD��A恤^��HM��v==�[ֳ���1 ���>QQ=����-L��B�=�f~��_)!D��p���k�i9�a�?"ކ�WȤ���~�E��'*{�?���I["]��$��g/��/�����IH�}}�#(tSϹ����F,U�	���~�����Q��h���<�g��<����k�E�E?`x�K��Î@{Z�ʀ@E5�2�w"C�����g?\���ƍ�W�j���J�&�3r��V�U�����(E�1o�8�l]U���!'�k��aN� he��MX��۶I��3bU$�^�����*�r�*�§�d��� `ˡz����Ñ�ek8"]����F���~"vn��/S��I�%-�(�X.a�x~/_ɥ��v!��T��y'õ�'�˷����ګ�$�Q<A�-������,׏X�nlO�sN��a����-P�r/bCu��HF�F	�m�^��b�p�HG���6$rOm!���
���,�bjI�؆�i�fEU�|R�p<=t(L(ۮ�d��� !�����X�=�b��$�?$h�To�0x��g)���"��
���VQ������ﴹ>�̮F�Y�5�۸����m��0	�0a,W5�0��3uRr�מaZoQ���y���fƣ�W�N�0^_ϗ�gH�lw��7x��uI�E�U�Q~�gaw��Z������\;Ѵ��]X�	S�M�as���iN��LA�.p?��o�rO�B�

{��;�P"6!I��e�f1�V�ʶpFS\Fyj%L��O<����e3P��
5����d/t���v�")�0���ތ��?�����Ǩh�H�0?Q���˪�m�#�q�ȅ���PS��}���uI]�PK*W���rj�x<
�k��G���EuR��~���DH�D._o�]��Y`]ZT��5������Ͼ�G�DY�d!m���j:=��$R��>�_��)��\-|��ź,�f��4�3��#ת�8R��E�1�Q;Cy��C��x1b�Gy}��FQ��(�%�@)���<��T��T��xuy�sQ�v��8x+`B�Vѩ�g��=�Ӝ�oW��T����b~�]Qw��%}Ǳ**�Q�|ʩ�T0*:?��՛� 8�E�ܮ�sa�rQ8��f�����0K]Y�n����4�r�=�
J���'��G�'\=��O-��P2�H��cZB��Y�m���g��a��rW�ms{����Pf����5QƩr�D�Z�
�z�΋��:*�9�)��B�_ �jP��ě�DN{��$j�)+w��aI��z������#�4M�ĕGE �f��%�w�Ĕ��{���+��.*��1����ȓ�m{u9e0r� �GQ4P0�\�g
r��uu�kR�f$(�����f�֪n���еy#ꍪ0�g�|���<���w+v��QRa2�E}	�(1p1��z��0�R�)������淭+$N5Fx+�ȏ>�Ƚ�I�4����sK����#��^yFף.-W�6MV͸�i���F��;����E�u�AS����گ{��U<���5iD����꺸�!.�fel��
���E�ًT��݈d*)�-�ۛ�@o��D�Wr��T`~q�"�dSnp���1�SZ-/ׇ�e1'�y)q)��������Q��5.�U��X��X�+�چ(��~�o:�0#߼��[4I�#��(_�c�fޛ�t�Uz���_L��n�7���cbnO ��f�ꩻ���T(~x���2�����E/�դ�`9
gGl#d�u �bv�6S�    t��a!�yͪ�0C#�N�/�Jg�W�Jҿn�?����s=A��"�m���^�EVE��c����mX�%�V5�X[u?��,A�$T����1?�;���f�a�/�b�G��uZ�&6��1�N�^��.Z��B�H��e$�BJ������jj�����8��OaF�=�I��W�R������� ��prQ�x�g59��$}ܥ͌qA�%���T�X���-�}��k}�ME�T��^8���K�p�QK��?H���Ej��ݹx��u�Ň�;�>T3�Vc3n<&n2r�jTU�,3�Ӽ��P�¬T2X��m� �M�_`�g@	�z�����D"��XBC}=-@�p���cYͲt1�M�ь�LE�m��"�	X.�e�[-U͇��+�8o���+kl%ff#n���m�� ���̠�u1I�>봝�<Q�l��k ��K�� \ċLC�Oz~�wd��&ӽ\W��]=C�#��"�U�'L7��"�s?@�l��P?��\U'Z�ߚܨ����flU�r��Z�n9Kɾ���WY\�V�&a@���c��PH�g1K�{��[����<�ur�r9Z��]�#���\������ku�K�,��D��I��14舙�R;w�XHc�B`����Xm���@r_��v��M
%��I�ޏ>ט<����O���k��~u>Y/��{?KI�S�^l���E1�����R5�$	T������t�q�Tͬ5'�]�w�ѓU(��E{[�P`i�e�8�����$=����Mݥ��f��<r��i@k2�'�O�����-���Q�F��q��mNmPl��R�j�U��.���ghQd90jʌ��f��˘7.�}U.�FԊ6�h/���qZ�Y�l�������؎\�x�X�ta��y�#"[�lv�s�2�6D�/ �،�"漧޼�/�����p�A��|V[�,w�M>CP��I���d���S�¼��4�tP�L3�f������(l�9Qr��a���DHp&C$��A�#p��d�����de4�}^��uQ�ǹ����Uel��������'W�D&��3Qxr�'�A�b�]	��g����r��m�����q����4�ߔ'�Dsm��=�l�L����'�$�k5�?Ԃ�4ï?�k�(D���Wh������=��]8��ґ��������~�����l������N.���0�8�=*�����e0\���,�tOaRU�zk��V�3����z��澟��V|�`A�3oJH��M�z:0�{�GE���/8�/,������l�\As�G����-FfϧӰuGx8Ϲ8=L�S,_߽͒pF����NOp�,\���ث�D��_\�C���Γ�&�._�U�"���2�B�_�	�q�C3�q͂L��4l�67�fL4/���5w�p�ĕ]!@m^��7�C�o5([b�iEic�~��9"g�6�~�g���e�`IӊM�Ǚ�E������B�i>��`����v��ve6�@�ɕG>J��s�w����ԯ��@E��̽I���l��n���q��|�q�����\|�� �x��!Y77`�������:q�v�j��Z��nO��_�d*�x���n�*<�i�#�UJ�.J˘�n^�N�z����=I~�n�6{1����hF��$/�7LӀ��F�$'�T'��.]�W�˕a<F�nMϢ�Dt�2�Q�ǟ���1���1����,�J��M4��gq�j5�f�{"�x��Fيm�	f��͐sOf65�F�g��u1 𶍲��<�R�@����o�=0�0AjxQ^�"];q����>������zD��v1�.���;��c��E�y�5"�D˄�͵����f�.�+VF=!Fi��z����o�pF�S�ef7��Qd ��-]��w�7��k�E�Yh���)����/-�3��w��1C��Z�X?�[t?~��e������c�|��p6����e��U)�����+����yb��V}K��Ta�g��;[�*I�g����`�N"P�|%-�wazG��%�No��%X���cn6�%�LG�=	&.�hjM��u�q�6�"���&�}�V���1�������l���J��B�p�Bo)9�*L�팹b�U��7��`[I�,4e'�6D;(���<����θ}]M��)u��x'��,Zm����Cfm\�^�qZ�*_�%��ϔXij��� ,t�������"��{�*�g���4`���ū��0�UXd�}�"�[�f)-�P��q�~���4�J>aTV��_��²���U�Y��?��oC�Ϧ�ڃX��ͤ�x��Ҿ>�_�����e:�� $I�xI���ϮLN�1NWu-5/�º�1�򰲬���y��@FGŔ�5���jܹ��PU���ǧE�[Ӑ����z0�WFe�If��P����]�/�r�Q#AI��]pW[�/�W�]���d-�<,m���o���l�*^I�l~��a�5���&�����E�4	|�N�~�'��"x�l=7����6Jf�X�2s�D�Z_�Q�e������%�P	�Z��Wa'��Ap"AZ_.�©:�{e�.�em�\͊d��Faմ3[���6����pw��ܘE��=��6h�g�	ls%Q3�V�L��sUQ���w���ȹ����id�BR�K�{#/ZKn�Ym�ܵ���i���;~
�p)�t%M9��bT����8�d`J������u|K<5����|�Mc����R}��U;�Ź���D��Zn��|�~�d�?9kʬ��mp!��w��	#����0�I���9�cpWS�[��U���n�I^Z����kYp�m�N�?�_�Ek-�I��7����R>)��ה-��UEe���7�eZ���e�;���
������0Z:bܹK�t���rfS�2�jt}đ���Ϫ跩4����v7]̓y))�*�����UP��ɦ�y�%�iU��.@*�P]K~gؿ����<�8N�E��T]<�=�Kwf58E������z!�P�=a��J�jW�t�*�;�*r]u���kbɣ&�������A
�<P�D�]6$`������o�tF���t��*��uZ`Q)Έ#��kC��~H8���1�#��a[m���F��k�~P�.�#��Z�%��ȿ��E�xM�:��O%j�337���E����p�2�e^�x�
fq�CWE�b�[��ِ��?�T"��/�~�������8 �����jf,6] zCg������R��	�:��HH-�$L,��������5��q�	d玨���b%�0 �����GM�J/�Y�*D�H�~yl�&}�w�[I�_U�_ ��y2Pq_�g6�u��aw0�3��H\j)��;�M�E1z�:��������W�<������]�,(�.]�-��>��^���ڮ�����m�{F�k�CSίT��N���C��z��p�t���b��i�3ڨ@n?������Բ�DQ�R8�X�������z�G�Ǿ�P*��_�U&* ������O9�_��XAn�H-Z�H+n(�P��J[�;���¿�]���*S�����n�W���V�]��Y1�m~F_�1��*B^l_Pىu��݆Z�����/x��� o�|�8����E�ĉ���$x�'$�1+�-�z��
�&=��fd��(����|[̰o���D.�4 (�md{�ȆD�m�5 m)�ʧ+V�X0LeY7��ҫ,�(e���{��)W���>��`�]���C�Ļc��"}�.�U\m�|F��8	����{�\�;�("�"&�����Drш����֋l5t�R��U���ɪ�
��E��H�Q������0�{x�p��ܳ:c�L�Žv��������,h&�,'W��,$I�;Ӌ]�`���u�o�:�mҸ�w_�'� ����������Y�Kj���G!�(���T�8	+��{[=7�]�N���QX>G+����N���0x�yI�
M;��鯍���(0<�i����� +HM0x,�?���v[�>z    �J��X��;�R�ޙ���Q5i�����,���ʭN���4��C
�}�fsbVU�.5�*xC̣I 
�k��8����4�=�A��õ�4�RZ�U�-�fF�\��2>y�^�S���՚lp�>��X�{�D~k8<��낿V�]L1�J��v��<5i�u)���VN��d���a����dO�uU��?�(Ylb~B*]���d�8k�m>}��|�A��E���,{�� #�x�u�$Y|3��E��e|g�rb~8tq���4ϴ;}��Km�'��0�c���*`����쓴����x�8ٯL��W���H�+$��DZ䕘#Z��,si57����IW7K߻ �q��Ⱦ����P8�*M��UR\�T�ך�r�Fj��vRi8��eaf�$e|�X�r����3����,v�����p@
��h�юS��w s�\��愭
maV���Ӊ���t�y�ިBf�����3㕯�m_�u�㤛/���iY�NA�(>X�<�p��%�&6͵m��H��Y�r�枺3G���WAdq������uůg��[��n����p���V�GM�K����0 ��WlB����f����>t��	f��*��{�U�*�����54B��%?�E��o�3������h������W]�Ȋ���t(���G��ըgfЦ(o�[�3Y�C�#��
^��r�e�<W_4�܊���Rv�����'���~�&*��]�7���~ƶW�EX�u��4<i�nN=\f�I<W�ih�H�ʪ�'Q2����Pħ]��U7Nq���Õ�>�g�J��ȥcb��b����k�	\�����������~��eM�
W�h,6�L�eц7�/
�4�+]��ToN�����4����k�[�E�M�f������\������b����2��/��!j?���'3������T-i�|	D�2t��?��޻�s��"����f�D�8*LֹJ��!���k�Uf\{=��mzYM����V1p��C+�Ӥ����(	C3U����{L�$�+����:KQ L��j�B�ӷ��:���V�,Ŵ�|Fˤ�(��Q�jgr�Xu��$ եQ+],S���VK�����<�+���Mu��`�N�:�-��I�^�R�7��1īm����E�'3�,O�Te�Q&�ݣvp�(�+��Lմ�QRy���0����VT�b5��bMFZv]3��&�YU�G�_����]��ڣ���^�u�-�e�H���Yl���q\��2DE\���/���:]���u�PF�\���Xf=a��Zm���4m���}��a���E���,�u���iE�=�������A e�F5�;�~�ǭM��21k�l;'fUk����d
 �w>O����l$>���ӎ����!Kj�l5k��[i�us:��H�Lc�����Mۓ���5 ����'T�TƤ�Pk�����V�c��۰���a�v���wḻ��Í6W{��j�j�?�֣#/�"�\X��Pp6R�>�n�?�(�2�Y�fl+龧r�T]֩1�w0������m�� 
��*���[�2����/W�f��3"�jsZ���`����=�x^�IFIjE��ڮ�j��oh��w�wr����K�VYԤɌ������+ h$�lN!Eԭ�e��t ]#�V�f3ڀ��x�'����[M	o99�,.�<��"K
�^|���
3aUq����.���	dw_r���A٨S�� ��`^��B�d�pF��J���� �-J*9�c��<��*�T��j��.�E2j�&����O�܋(~=N����`.�Z���"���)�(ܻ��Ԩ�y�	>#w�jՒ�������8�Bg��d�m��/�=��17�܏��z�ڈ�{��ÃвN���|3�k�f���pB�G\ʓf�L(x"�9�����aߪ��fF*�MQZgq����w�����i�G��K�=%�M�+�-�~f,���Qt�������\0�y?�F7~6 ������j����uV�区&-L@����5]<=Η�9�H�U�=O���˧�eEؔ3�tV��G��[��he������z��C�߈���c}��������bYV�I7�@�˸�4fI�J2���ӟ���)�s��ם���m��+��o_ȅ����?����(eY���o����84|2�>-�ɐҒO�~h)9!��1��j����׮>}_��<�k��}�RKìi�נGy�q͂ל�m�������Py2cz�������2l�D�{`�
?ME���R�Cț���MWӫX�o�ʺ<�g�����Q�:Q,�``������A��Rd�M�1�����U��j�����*%-6o�t������j>��߾+����I��=E��۹j�
�
ф/����fw���<��f���r�x�U3�'I�
�s�r@?g���e����� �Ȃ�����p��Rm�1_Mp{)��*�mv��M�/�:ꋪ`$d-��U�2�La�T��*�����h��=s�	B�Q�G�h�ZQ�8~5��?�0y��ݗ!�'�Q�x����䅿/�I��8~�O�.������*�o������b��y����+�$�\����F�vCSAf>
���|��!Q7�b�ՋW[	Uq�$��y�dŜ`�M��8��*�ku�f��@&���xPWB���4g�.z�+�<�vF�H�(�sF�b���
ͺ1~>Ow���:6=c(}NS p�~gXB�z�oN{�Sx5��%ܵ� �*��J��{��n�N�El�8j@n�6�5�(������O�gM�>1M��RY�"΂_e��&kF������1�n�'z�P�p��#�t��-���2��a+���y�4��;�'���.�p9�[� �
�X�H�[�Le�8/���q�\�(-nE�S���4��|�&���ACG.baE���O��l^�I�郞w��>��f����2���r^E���2x�Z�Sm~��𪚪�Z���4��W�qn�a;�e�֣�,�Ε�"�Q8��j�%���Vv�r1&:i �SG�*WCv.�e̫��S�U���$>��[aQ��\�v���
7�#j���  +[�0nՋ�/���g�&�2sGK�?ᇆ��S���8v��z�ܐ��θA���-��ض3�*
C]D&q�Q����`I+͏�����T�<1�ɺ��x7�*o����<�N&�ϠaG 9��'Q�� 	���?N���w�."�L�
�զ#�!�.qe���J�8R:v���'KF��F ��^�#��I�]�O2«��.���0�A�q�!�uȖd���Pô�w};qD���F����z���iQc'Os<F2]a���K�-�uD��`�<cm�Kow�:�o�j�mj�����[��)��Ѩ'��V��N�����㺚��b^�U�M7#��{��+b"p�zt�Z�z.ʆ�E�6;ד�`j�{"DD(���H٢͋m &��+��z8<W@RD�]�֚V�g����Zت�	gm�!�L�)��Q��|�aҢ~���.��q�,��x�Z5 ���g�:ׁ.O�ў2�j���#͋��U�,��'�D��֝��6�9���ݿd�%?'��LL��n[����@<�f1�k��l�b��@mf�mӤ�}1S���;B�>����,ʹ$m��G�D�������?㺶�<,QN \)�,RQ_��!h}g���#gG��=�Զ�2�M��.���	g��ɶor�o��i�w�ãX�l��4K�4A�u�{����!���`�-��Fx���Q�0O><]&�����@�x篸c�]m�0^��;�~�k�=ݗ��{\9Z�q_��3H�2�,+U�����E��B�B�~4�e6()�5���p���Y�YH���g�Y�D�SwX4���4? gHW>p
�O�փO#QQl�}cG�2��;�]�i�+��}P�՛��
w ��1/�L�i�p��n����c�x�O|� �}�Y��!��;~D����}�>-    fD�q��1ԋ��n���×'�f�S
� ��6�R�vj1�cQ�Y6��+�4� %���Q�pU�ކM���������w���`�X
�*�M�pA�5gtW���M�g3
��2g�"M]�=Z�}E�B.гԓ���g���w,
�5�7õ�-�r�Ң����,��oY���<S��<aD����bxڢ���,*++��<�ػ*�턮�'�D5�D�	"�����+����� Ű�vٶ�s^d	V�y>#;fqY�vي�7��n�����i6�4��R�H=9��2U-�R��j��b��2���c��,��X|�l��M�i�����_@�:����n[|��O�B����Ri ����+���o��d���v+]c�w:��
jc�Ž���mT�W�6Q�AW�֏ڻf���*~����ܶ�@�L�mr;�$��8�*%I\������� � y�\SP��;��`�K�����6���^z�cR�����H��ό,���g���@k|V�L�DR�i0pь�I��ǵ�l��>0t ^=�h��W.I�����6m]l������<S��"�i�uT}.*L��?Q-�t׼�Zٹ8z��EO=-�	��#ވ�`�kB��%A�ݫ�w�`[0��i�ZL#]Zpܠ��^��t�f[z��ߏA@�\��4m��Y���f��v��P�D���'�O��w؂�}�\�9U
�d����(��O���ڥrk����1��A����eʏ\b&9���3ǯ�y�V%,�~�6n]�(�jD��T��,	T�Vݔ�R�� ��i�����r,�ⰼ���'�g��]Y���)��&k��� Bw��l���
��м�������ի�*�Q=�g^@�zhɸJ�#���_�������W�Y| nc��,:���S��hb��!�����;-f�OѭO'�L'~��4&�t�pv�H��_nb�Q1@3TT	���Y]��G��O�U�����o6xzz�j�����~�=�S�x�/>�D"��Cdde$��Z�GêLL�m&Zyw�����m��ge" l����ip�:$�`���T�2��-�iw��7��[�"���ju��u��9�i���ʃO�{�Σ�pvD�jS�]��Q���R6���������DK�j��\O�~��mY�e8'�yh(�LM����Q,�IF��O"�ȷ��5����PsZ����G,���޾���(-^e��eJ$�Zʮ���2(���C�m��桫i,5W��|
�yJ�R+{��M�z�]z/]9��g���n�������i�Q��_�U\��|�:�RՌ,�0��Kfc�o.����yzx�@�Hؼ��-��eD ��T�������c�a3�ơM.�(x-�q4K�������.�CH]\�Ο���b�����i˫�%w�X֓�\J=��f�M8��1^C�j�n_�\m�sW�5�RG����P��O��'rS�I��j��妐UX4��m]�$��Br�Wa��rO^sI���x�KQPt�5˗a��!Pa��y��.�ed��$;�����U��A��ib�WyJ#"�w����p�݅Ur��%��M�A	�?�zE�@>\Z��p�qy�f�W��Z�~S%y?��/���γ�8�3p�]0	�#|Ͽ����PH��9m~��R��9�4�2-V�q�;"bBf@������!�����S�у��	?�J:�W���&�`����j�+��>���'�һ��u�\U�HP�J�>b^���̛���hG:l���G�҈E{㍰ÀT&fD�;=Yv��p���H�M}<Д�fF�ȻJ��~��Q[���h�&�AvU�WwI�
�'8>��LD���^��$`�|5���j�*���v�I^ض1G�x�����+�bHfN(WZ� �D�����C�C��|A����;mPc-��?�T�G�b�{�8�R42��i{�nئ������e����6�h��ɺp��F�JB�*�]�8��"����#}bd��VNT����C>����]2��/Ɣ�����T�6���*B���e,��Bdsݡ�y��~�㖫5om�G��N�P.��ia������U[�3�.E�^Y�(U$��G@z���N�(��;D^�������SX-/6ϩ�0�f�8���.bN �������߀Za=G��4edV_��f!�X�-��Eg�]�$xS?o��zQ�5� �}�X5n��S��g)<�������u���[�"��X;Ⴖ�ܛ}�O�̋%�k�z�q�X�8i�7jP�gQ�X�[�e;ctPd��E��{vCFl�l��8�.�]���+5��������N�9?�����0T�a\���b��:����H��=by��c�H��W������Q��,_��Hėi�'�F�G;��6ˁg�@��Pu_Y/̼���`$��!���#W~ԏ�Л�7�������� ���#�]�d����&������	��i8�;H�5{ϥ��俒�e�3��dh�c��jM�j�W���Y��7�	OLN�(���#�ȫ2)�\�B�e`���_��j�AƷ���atT��Ϝ�IPw�Q���F����כ0q�1���}}��R�� �B(?�ղD���"�T]6����J���j�&l��EyΦ�¢��AG��c�
�s�<{=
]1^��Ж������ǰ�\�`�2��`F�թ�T^���`!OY8T�c�/��Z��i1w�����m�ai��}.��	�R=���F)N%]N:�������.N��obGe����5G�� �L}(/>���hi�L��!AV-+��ͻ+6B��W���揸�@L�W�9���3	^�VǷ�j=lU��[?����ՙ&�=�t����S!Z��Ը}�pi�&Qe�K�W�x5멓�-������&�h�
�����6�+dl�*��9�4Y�v�	p��u�2�#r.�1���B*2w���G��ِ���f�җ/���nNn��(�ڷ̃ς1�҂���	&�K��kC�D13���ie�-B�As��,�4��,5���L��M6�I�ȹuy�D��]d!Hf݋�h�m��A��LV�R[`7yT3�^f6]*���p� 	���?=�r����.��^w����#�"N��(�jKl%	��g�|1:zS��ʲ�2#��U��+�}�WE��|wRO\�?7�J@�eTVs[��k�m3�'���<ҴZ�.q�h�gWf�3B�����9�F�kr�ERş��I��!鄌c����ra]�3԰��*}#W&S"�N��{ ��	�)�,ZD/J�xw�V�rZ��ߴa��RT�)>s����O��;g����d���C�`Y���G�)��}�^c�x_�P&��zz�YG�\�.o��;3��M��J�׀2�s�Ā!����[B
"w�Ǆ�����/��5���n/Q��PY�U�47@u<��q\��_̵��v��r�?�b�ʂ����$� <�)�RlD#,F�J�^1Jp�W�~���j܇��W�Ir{�UA/]��*>��L�(����(�v���K����#a�[
�}���������̌�jJ�˽�mR�3�nU��Y�gxH�r���m�AQ���<�/�H�X�V��7.m��qF��cd�5U|F��l5������~U4���(��R �I~�����!Cy�.�͛w�	�P�p�
��q�VjXny��m4Û�*��ԝiUﯨw]0�$��E�O�l�75�E�*;Ss6��j�П�;'���7�j�$��G�G~a� �?��4�"!zy��{�y��e۷�~ih����{H>���P`��j�+`u�a�U$���-ۼ�/H����UM�V"�J���ǝ,��G� �W+L-�
�!A�?���9o��~�����fi�!���T pN����ҨRI�׶-VԴeݼ�6Jy�e�}O��&Bj��;"ضeh.����@]g~�����T���(�Z�;\D�V}t�'��    ��Хk�W�=!9=�³�*	-ޕ�o�� ��}>��uǏi�\�\ؚ"�������*�a����:Q�|E����{^݋Aq�&�yG5'g�س�E�wS��]O;q��������o#��i�jD����V� �s��U� Z=����J4}}��(Y��C	��j +��x5�Ŗ�m_�ٌ�2u����4�4a��@@�8k�� �	��N*ЎN�+���䈈���/�µ{Tm5x#��%���Lo#�d�6�em"��D=F��R
�2S@�!
P*�}I"9O������m���G%��2F%!_�z�{�k]i��8���nMP��C��Y�=���8���R�.���g�2l.O���2"T�����/񑻶�����я�����ua�޼�t'6�$���ɒ����^�Ih���+����@�Ed4�L<D��}Rr��_�](a�*���Y0L�@�&EU��r��'�g������R�8NP�a���
�ʾ�p���ϻ?���G�WTKW0��:���b�Ґ\(��~�:իB�#o��,;@�������>.h�q���W��Q�]tS�r"��?�/L�Z�!�P!�mM�VE�%D
�O�j⢋������s�Ui��6>+`F�D�������<Ǽ�z�F
�-U�t���*q�;?�_��ZM�d9٬.��jF�W��X�E P[�Ѫ2�5���~:�з{���^)������#�f�KӮ�q��2*�f*�%���뮊�=���I�?@�q�A�wyt��j��.n֔7O�\��"���U�7h�
3`KsAƟ�'��)T>��$��!���M�H���}͈W��V���uj������kQ�@�Υ�9D�2K�]����#Y��v��v�H�Q�~kݟ)��� �3�*�Ro{nXbO�om}������~s�Ye@-#o����)�p���b&]�f���{�0�2��`v�G̴h� ������'V�.�����庺�3%�"�-52I�*s(%���Ww��ѻ��#��A�(�3L9�o���N���傹P��gQ\$�E1^�){�ݜ�nLs�u�� ��]ӻ��Ǒ&^?��X����{YC���ͻ���<rI�%vE�@�0���adRu����"��c��M�!2�n�1��jS�Ő�]&��=q��yl�"^S����A��:�����rh��A6��([����S���.�=2Y�%�B��Y���|���$�2����w�OT7V�la.)�9 �/��*b��*�����\lӇeω�k�t���P����VB�t`��O��P~�r
zc���b0�:tG�,o�U��0J��8�z�s�G�.UE�=�F�@= ��}Rg��L/�*[oȿ�����*K�x-3pA����g�����/�/gܪ��|YQ����m�c��x�y��hh�ۚ�J�[��"ˏ�˛��i�i�e9���S��"��|Y�у�K���;-ٕ��=C�ě�I_��C��؎� �yޞW%�D�w� ����)]�Le�S�rR����HU�)V�sN9q�џ>��3���������:��j�0@F�@����w�^���`��W��[��I���m�J��8T���p@������x��|~�O�0�>���/u�4
���k��V�Q� B�+ع?}oY#��j55[�8\��7˨��Y�����e�8>��2�vJ�������̽B�X����r�.����#�<�ۧ�Q�E��$��4�V���FE�)�;q��RF�"�uso��ΌT���{9rd=��s)~M�e��ZԒG1x�x1����	�s6C�)��>S�w�1%@�]Ǚ��$:"fX<:�c��K6����19�"d	�A�Og�8������R�]�˥[�#���Q_1:�x�u��E�WX��@7ßw��q�`�8�l���|�����nT41]^�Y�'�i���i�X0PoS]���:�|R1W�����)(#ݤ[~��52�n�Zǰ��A_fE��8�U���q���+���ɤ�;WA��n���t"�A�i�K)�vއ�֭�M~�*����8�_���[���S�⿯� ��i�	CmQ�;�He�ѳ���u�4�'�8N��o�W�<v�����cr�t�p��$71_m�؄�o�m�RU�o�@�X�+[�H	@�'ݥy�i6D٥���=R��Ey�w9�xߖm8#�&y��xe\��}�T�|�����5]�9~�����|���L�̱a��˵ܣ�A/���I�d�2	�_NbL#��ح�����I��*/;y�)bIh�k3\�����]@�������}�G3�@E�^�$
���0��ӐoP�կ�����^�P��%��l�(s�?%:���H��h��[M�f��~�m�2�QW7hA����z`��d�t	�b��;���<�X�~��bu%a6�f�U�-�$x�c/��)�`�3�6	���� {ZeN`�CMP�(+��a�����2Y&�q�3nq�F��H��G����5;Mт���e"�u �8fA��Sy��m�����WFc��Z�.߰��O/�6����K
���V����/
W���YUQ�&����j���lͷiV��P�j��I�Bj4�U"��HZ�jx�h���adN�Ob��n��x����C\�Ujٵ~�
(�6�C�KjTMr�b���{)m��4y ف��Y�*~Y�-���v�r�uw��(�$��P;���#���?���C�+E�d�>��MRP_8�bD�x7	�@��B��C�wjJ�oj�"��!�����|��W���I��E�����GAW�>wǯ4�����=�g>[���5��#��	"���-��!	_��޼'GZ�f�V�	&�9�X7�,�J�3D��2`v��kB�M#f��j�2��eHQ��9ǮL�Թ�":���4pG�䒹�I�8�V�eY�a�6(�*YO]t1 Ķ,��v]e�>�i��\�h
�����w\���,Qg5 �r[�mU7��I4��p�F�k5]R�Np�=2�Gt�0�;�b��q��8�ںp�&��\Z�۰�}�$�G�:.����J�%ԭ5��QЂ�ź���l�ܙ��
�(�	Ir%q�3ZmO�\Y�tI��g�D%M�ϴK7Y����:NS����(�Y��S������܇��)�믻AL�(������S}���������� }�3�5��9͂�+��x�pቱ��fs.��b;7M
d,���>�����5�0-S�_P`�JE��d�;|z����P��n�s�����R+@!`-g{w��D$C�A�U$F���1IY��bd��tL���!�~
�G�.	j��:f-�Q������!kǚ�N��V�/f��݆�f{������<���<��5N�~��5�����Ь��Z���0jf�x�<SˈCC<�Lл��a(Vs@�5LKm�t5Ǻ��u�S0�-�ؿΥ�ܹ��U�����	 �j�%Q�0/�ax�O���A��� �1��j|�� �q��3��2�"��������Qt��?PW��T4;]&870������n$!��-ުä�O��ǭ(MF"�/�T�G�>=��ܟ H��/�Ҡh��������֏brB�ؼ��%��!}䪳������j)Y�:L]sr�j>���I��	�cu4����C#3�~��g�[��;�v��i�EbVt�:E�J������+O����6[����h��ټEr�̱�Z��jȢ���������qQ!~��^�O]g�W^��������@s��:6���z���������hW>2��j��R^�uXmo�qqu��
�`G�{͢�~�yDd���ǭ��rM��c��㪋Q�^��{6y�gD�]Y]�fE�i�Wx%7��D+�����X��z��ܯ�s��K�h���W.��s�莫�,_͈`�ڹ��v�]O���Y�`�/7��3M�xK�i�����B}!Մ8@;���e�/�#]�}��:�����
D9��»��y     A�R��ǭa�r-�ւ�������=ܑ(y�2 �b�> ����`�)���Z��P~�e������x�,<�Z�x��:
�.��B�0/�1̣@����%ѻx���Al �CT��&�>��_#GQ��3��E[%���/GAШ�c��i�R g����|��^�L�$��˙�=9�4��Fh6��o ��׋��Q!	^1*�t��ڇ~D��ά��JʁH X�hˌê��'U����f����bg,9ޣؙc��r�Q%I��A�wR���h}��U�O���*�Ba���n{��;`���߬�5��-�����*>���������5Q�fጶ�,b��i�Y�ڽ"��#�@���6ßE���S���?N-l�h&���2ܩ��j�o�~~�S��ڤ����cy�L��^sf��_mzd�(i�@ ����T�e�;MU����?�ZwK���[��x� "Yk��A�;�P7�F����F�������a�Ut������8���P�����9��n�KM�M�o�e�>j8n>�q�v#���b��ɄJ�>���W��������
�vG��y�Ys�.�|����ky���ZGi�n�'��R���<���|�Ɣ�}����*7�������Q�t3VY�����n)[��q�wt��A�V��SlP��O�f���<�����e���	V	ù���r�'���,,K_����CݖQ�T����9��wJ���h����t$���[m��`������u]�CW?��x�G}���tU�嫈7��)��H>ccLx�+��r�$�_�gA�2��jP���e����g@���]za�e�C�-��*A�[�G6���{��S���#I;�_<lQńѽ�l�e��&��R=8�C��xb�.���b\�1�O��3q��B8�S���U�d����fK�/����8�����r��8Q�P�;��2J�?��
?n(���S"IH�P��qt<2'4�N���+���p���8�hb�N���Xk.��*mo��dq��yKYD�߀�x����S=�	\c�ca�т6����n�wW���|T}���S��*���,��@~��I�MjR`��'P/�9N��� ����M.u���]M��a�]M��tl�L��	�{Q�Ɠ�j�D�����C�G��0�RU�q=��R6u�&Y7���U�T�H=��d(D?w�1�"A�$tb�Y��F�Cv������'����hqo>��T�������o �u�S�"�ll{d�Rc�MK���~�K��w旃?��A� �nƔx�y�!�c{x�c��T�[F��~��06�1����$�����������([�:�����N���5e\�^�]s�z���oG.�^�暜����2��#Y
�^G��֬p��,x��fb��Di����n��X�Jb��u��j��{ �(��th!0%->��K$Q����pd��D���F��gM5C,N/��j�Q|њ�f�|�[D
c��ss���0��O��w������T��<Pjד*� ^'y"�DH�����������LO�\����}7(���#�O��Fg,�go7��f������[���慹9�E|aI��'zr �+�$D�i8ʳ9umЧ���z;�(��E��8L��B�&�W��AE�֏�2h����nb�n�8;g�W�	Xl�**�Q)�eZZ��V�Ǿ��x�9�
*E��a	�z��K1Y�8��lF-Syn%aHN�)�w�g�"c�)�
I�&X�ex�� ���lq�m���[�q~�0`���}�ў�#�DDj�vR0Y�G/[Jܹ��$�����QYoV���)Q��V�*�ʍޕ�c��+_�M�ged��,����j�֥D긨�Xg&qT���\�w�������(SA&� :@[�9�tJ}"]Ի序h���w˼�UZ���󛖺)��Z5��E�YtY�F��s�iŮ��Yz<�8w��������d~%�q�WKK9=�q��3�d�4-,�i��q���F5� ��j��c��!k�=IM�S��:�f��SYls��5˳���^�l������ݿ�o���
5Z�BRRZ.HG7���z
��f斪:�3_��jݥd�긫�|ƕ�a\���i�E|�(	���O�v_?�;��rd=�u�y�f:Zf�����7��~[U3nu�z��Pd�+[떟`c�J�)⃅� ���q�ز)	󰚑�˨0`Y�^�i�t��vwf@|��ىL<Q�k*�R���ϣo�E�=�(�@���$/�wL���d�TvY�l��#�Q���CY�����0�=$�E�Y�BD�P�9�/q����� �v	E����;f2��u���T���-�|��"��rF'�W�y`�U���d�^]�k��ʆ��ȥP���P��M��$I������$�}Y����U3� �h	������Qg{p믽keQsa!��Z�<[�d�U�ω[��5b�tl?�y�i��^�d���n|`\�'���0�k��V�jc�Ř�I����n�}VW�bȑ�Q���:N�`�!�kX�@	I�c2u�����X�$��[OZq��XRi|{Z,�2��-	>p��B[�t4P�����GMP�G�M�*��@����;ܴZ��Xg��]5��[$ER�l�r} �XQ��^E�����#���~�V�uR���"����b�:>c[ғ�����T�]k���
QW����b����� ����ŀ~><O0g�|i��P���L��G�M�SC_}����s��*%L���{��b]��G�_ef��R�ؿQ��樢���+)ӟo��:so�;_�-�wd�ʫ��U]���w�j%������rWYv�?A$�x\]1��%Z���^.�w���T9w����h����f@�,�+-�<��FD�H?��/q��]vX<�P�G�~K�2���I�Q�l���b�䤭��EU�R�g�m��Q �|�bc)9�:q�.�<��J
�}Ut6��O�g3��g\$ۤof��p����
^)P�L��B� �FRR��=���@$�1��WF�����W�jK��R�0�g�ۋ2KT]�r��n�?xx�Ie�;ȋ�]��D��Z����˓FY?c�YT4BQ���`�p�-��k�Ϫ�\tl�}U��h���^-^��\���_�2���
������|��lû���C�L	 ��+�������d`u�z���z�4i��0��E1	>�<�U��.�M������d���ݿ(@�Hj5t�r��4m�7w{��4Q��*L�W����b��u�=%��b7܏��e�^��L�8)�e��
Db�*�y�@r��z�ڋ�s�� ����C�w��<��w���N���S܎��҄I��Y��2^�4�u����i�6�X'W����Uu��K�C/�M�����#��t�{��b{�趮��� �G��h=���?�G���j�s��#ͪx;�r�_TS�*̂�4��j?����ZC���hAPR�N�h��qgv5*�bt�4���he��OÔ_Hw���(Z$ha�Bs'�*�y����p�#��p�N0-�v	�L�4�ڢ~�6�̞��B�A]�YD�㸀�&����j��q1Ç�L�(��U�N7��-��/;�h1��*�s�#v6v�E`�ռ���L]�8�jH��_�+����@��M��%�p泀������Z����v���꒮�)Wai���#���3�}&8�{2h�sU�7����%�w-T�����L�ms�hV/�ԛ�u�̸�YRX�E����ެ)d�l�X������3[nD�6U���}��,"�R+}�Z�Ǡ�v6&�|c�E{����3ׁk@����YL���Q��
���Ε�8E�t"gG�zX���/5c�|�H�eu:�QZ���34E�A���{t�ʀ �	��i>��xV=���ŪX��W�^�1Ε �Lpj4�?���"Ii�����FR�ޯT����    ��g����!���!D8>y�GU�`_d"G
��>i��F}���zj�HodvWO�1��SL��5�YjH.���D�<��y��HT ��wéGw6����I:���:.Ɛ����׳����@L1�F�B�i��i?�H�QU�ΰ�ŀL<�u��m[:)��+���4��Dw9Vt/6�O�Y8�P)S#�VQ�j^Aa�fZ���]�
�^��@లW`�\�{�vA9��Փ7�	���n��pN\�"���po+��?��w�Ӥ�e�!�*�R�Fi=��Š�YV3��e��N�T
]�;iO?V�A��TQy¸�_���چr1��,���4�a�J{ت �+�~*���܀Si@�T\��+W]X�{��m1���
ݓ��p�7L��D9��4��+�Y�3�0+ ���jp��XYRg3`w�PZDOl�����NG����{�`�v4���O�'���A%�<F�#�x5��r2�YZ�ɜx�Q��V��q�o��*�FX-�j��E$��t�D��b9��X
o��;�wN�f�h��qY����7�s�4	~�U�S�5 t�t�B����NT�e��q���Wlٱ90���ZxS�c<a��W���Cm_�V��y[�=��~���~��'�^�X}�:�%�����1�@���(�ir�˯fM�+ؼ�K��{s=��Z�I�_�d׻T��)p�I��N��r�u�u�3��������x�8u�MހG@�w�z���x�o�Eg���0��<�sF�\M�8Ć�tm���z�:�#�ְ �j�'����)��O�D.Y�ӽ�9+�:�}h\%�-3�	�[����Y݂���GԞ���r��e�{{0�,R�a���]׸]d>��Q�>��R��4t9����,$�z��:�:�
[?�j�%�k�R�̌�zj��3�{�3RtZ�60���(��+J��4~�x3 �j�p1�aV��l�󕥹�#�2��ϧ���c��y�C��FҜ"�0>�j;��6[Y�
�&��Ƨ
�+:��9S��Bc#,�P5��7Pc�|��E,�z=��R+�������������0�q8�Gh׎ ~�6�T�fx�Av'M:�f�J�I2f�zUD�.�ŷ�.���In]|�iP���Y�"�!�YȰH��D��w��G�f�{Gg��e�F+���@�U!��w���Ax��~��|�nW�$��VQ��t���^�H�OG˲j���^�f׭�!�u�Y02�U�DkX�YG�Q�����)�m~�ĳ�a���Auh]c ��2P#���F-��g�� �.��Z.�HQS�{����x�X� ���Ȯ�����3.d���bA�$��;v���`'�E�ڒ}19�l���%B�6�N�`�tq!��	�ὁ	�٢XoQ1G/�G8����}�z�˓`�Z��-Y�s��U��VC$�u����U�=6���|�۱�W�x��ȯ��_�X��J٭p4b1⨰��F�Vq%�\�6�����Ɲ'�؛�cul!�މ6�y�퇋�یj�ڵ]�I���?���}T�BY�UR�L>O 2"zI=H\M��9�ZCd�F��[�|��%�˗A��6�d,W�E^N�1O��V�b%Q��Ҥ>�/  ͗Qu�q�88zn�v�<�Z��j$O�7S��ʃ �*x��&�r%�¯�n�n���m���:r5˵�ӂ�J]�V��TL�T0�5a�{%okG9~�j]/x��n���3fԪ�.�b��<k�[��$�
��(��;˼}���V����W�����V�MY.3P��6*�r?����8�nQ�9�,:G���+i�U 7�>j��I��k.�J���=j)?�ʲF�j��p��}�];����N3�h�צ+�J7��TK:�4��LxD��+Z��vj�Ǖ1���R�__;A}���������m���2�$x�8��Wݙ,�m%Qt�����Zn��e��j;:��*Xd��Ae�}�{3@�+"���]�l��9�<��Qϩ�ywU�I�<�%��f[8�:	d�#1t�� �G�@�B�^�>�Eq�\��/�"����94�ۍ��*<�+0+�����D�e�*t��kO���þ��h�j]��F2��:u`c�Ibs{I��L�xk>0"�R�8��p��:�.
lx&��K_^���%����f���8w5�TS�ǁ��zR5{�F/J���
�&o��(�a4wv^)ay��U(�����ĭ	��%�oU=/��#����	�>����q�i��9t|��"ǌ�߆�Lv��^��Q�B���x��}�`=eS�*��g�<����,�b���W�N.��˼�f\�`�����{��^���M~��e���5m\��� \�N:���v�YϷ�Ɣ�,x�ف�Ā���؉����F��+Z����ӑ����i7�}�?����JW�Zʼ`\���Y+�̤�%y R����TT��k��7���7X�}G�"#�����k�˙�v��CemV�3�:�+b�G��'5�
1�p�����:I,*vE<��a��f��`�E��
�+"�mN�#�A{蹹�J�EuP<K�6��mG�����ܫյ�X�a�u��Z��b+G�����W����963�ٓ�5�Ab��
�σ6����3���Υ\o|n1W�<ʫ���V&n�u�4�y�Ň�і��L����	�'��<ˍv���ju�ź�y\�݌��Q�/o<�Ta�&\�>��I|�6�``�ߗ����A6;��ñs3��m��H���se����%�y�U����0�M����DzF�T:�tD=��Nޜ�xkl
��f���a��� ?�Sw�U���V��.�A�Q���/cYD�&xh}R$͐���+���d���=��>,d��82�m=��b
�<Ϻrƺ%��'i���wJ�3鞵����+f6�WN��N$�z�W�K�EZ�y�W~�1M����C����z�,��硔�yk�M+ˈM�I�8��Q3,R���M���y�0�����0�Ko�5~�%U븴L��]�FC���d��)�Wq]ݞ|�y��aZ�6�#�͕�ED�ھݼi�n�2c��	�*���.�x�*�Eh�������[Vs*�r�v�Ɇ�9�b5�R7<��>��5`4J�d���4��#h� �Җ��i�I��j�\�G��^dr�?+���"7����{#%G�I�2���DDG*�H�bw�����8𵬛a	���:q�u�Q,�!/kp��XR�l�Q
Q���LPT��� ����	"y�d�rZ� ���+G�����Q���la�(3�P�FEYLb�7u>���}�žl�4y'�jC��b�O]�.'N��gjoFd�Ie��j|˩��n�D3�c����da��y����*]Q"E���Ď����}���uf���{-@�~ȅ��05�]��#�$Պ�7�T�Gj��.��^�����g��t��E�۵�'(���� A�6��P/�N�R@�?�1���m��\ʿ�ڻo%���F?ţ���w�=�`�*B7�=�%r�����S�ȀV���K�m�nw 9���?=��O��c#�Nhw<�ߍ�ئmr��!ڦ��W2x����~��;Ҫ}��&�<����[�,r����n.��f�)*L��*���R��)gQ�
,�æc
���`.qc)�/�F����&�\�<���zܞ�EQG*%̒�gZ���X��bq��Q�˛�q�10Q�4��������\���/�&�]+�Q�ڋ��p��lR%jB�&%.��*��E��r�����zBq~���^p���(��
�7�(��a�FnU��(�����_P�~i߮�Z�L�m���<�M�Q���ED��R�Z��L������$��!�2����x<g��0�{m����+86����,�*�N�����X���J"�HNB|G3��)VW�O� ".�:�!͉�0U��+��,�21@Ѵ���W�yڃ��C��R����Ռ�+e>mno���t�e<@��|P(�h5)�
y�B�L(і#鋁.
�C}h(�� �  �wqp}��RH�\���#��,�K�mugV�pR���϶'j��@����3���}���U�B�� �Q��H������3�s���bR�µU�X�"εL�����C:�f.�4�e� �G)NrY���(��v3b�<��t�6x�F�8
G�Bάbg(i��w�j<������*�vT3�+�$ono�����픇�ƉO=��!,sGv��I�jr�e^���r�h�(��..�%
45�t@��BN�E�t�D���[���z֞�A��Uv��,�M�f�Zss��h�����l��p8�q�;R�-Xm�ȁQ*�ȉ�������2mrTߘ���{��E���[�vn�����笟��Ur�7�ԓ}�fFh�c	>�8�Bcnb�P��j�k1�������>���7O��"?�>?8�&��f�����HV4Э�-�NveO�~��v�-VpQ]f��cq��F�ʳ��0&!M�T��]������R�G<�l��&��~�W�,�K����P��qZ�a�ݘ���(����)�'3�0��Uf���e[�&m1e�K3W�^S��8Om���סWU��0.�w���,�n�vi����M�rI��	�l�E���Mp��_�b�Ai�z��vT1۝Lz���u��+�
�%_M������]Q�X�l[Xo���m�4t1I���O��p�F��lY�[��	�o�nb�>����v=
�b9�si�̸��mn=�bB��%'����ŊكC��#�'Jp���!����P�|`I���jT��&6\��l�̅�c�.d�.�\#�������JnFT�q7�	�c�̦�����yS�6~a���Z�:����q�
�.b��T��U��?`�CJe�4) is��s�z��*o�v׷H�����w$�K����_SѸ��f��b��~�zCY��lt'����8�%�)�f5bɂwb����{/ٺІ�
_���us�x{����~84���isGo;%�Cg�5^MH��kb�����$,2#�Y`��n��3C�ũ@���f�Q���S�C��H%�	�sh�Ho�J�Ϳ�����1^GO����e�y/U/*�o)o��|@�(��^Bt�}�1m�c�o�E�Zh1�l��s�6I�e��.xs�Ho�>|zB��z��q{ǎ
C�ᗯ�l{Vՠ7�W��[d�YQ�P')��j4F���l3�ASe��P��_%��-@�
��7{-{$]K�s�=�v�/��y[�Y�,c\���^-��29*�a=F��ƫ�K��4K�匨 �s�ú(�]a�XP�"T�:�t>M���|i���,)r�j��Ŭ6Kh[gDE�����{�{�B����z�9�.~�3x9��B�C���g &n[�
�%�q���Cv~�jv�z�2�ҡLTQRt�q��d|��}C�`jX�D��	�p��傅&.f4GR��2[�4���9�CC
E�ߒ�B]�oL�kT�4�z�M&d��HW�?!����������+�����k|T	 ��3��N1w���O�K0��^���Xϭ�{O�3�*5ڝ�?��(&��������>��XiQ��� �e��P O�t)si�h/����&�3�C������~j�mC��Vઔ;_�?1D�9����\~V׻���ӜA .�a:̖�:�ɤ�l��O��pRY'�Z��Ce|s/��Z4�>6� xP&TV����[v=��b�h���$�)�>�.���O֠�邿X��my���z!Y��΢N¯M.`�ϓ���.x8V��,&���� ͥQ>�]���F���/�	�Vؓ�l}�J�H�"�ݼ9�S�+�FD����'���zp�8�)WQ��G�i���v/���	$���Pʞu�q��q�� �c�Vq���٤I�+�}��ÌU�S��h��1�x�,�YX�n6���j�U�5r�e@���^{�����SG�      p      xڋ���� � �      o      xڋ���� � �      T      xڋ���� � �      S   ~	  xڍ�돢: �ϻ��fvlK�m�&o��rQs����EP���=�n�ή�3�� ���>m���=�J� ��B��t���*�4�����^MV�ӟ$K'�a��]��Ե_qF�1G�p��O@���_�_�+���'�=�H�|�/R��-P�<� 1e�'��A���7�9i��j�ogAY�J���Ǎ`2_���7�ow��%��cl?g?��_3��3�B����%S�.�A�n-͜�F�V(ɪ̘�$����Y�t���[�8�o�/?q��0��e
=��<�����ysi����eZĤ3J��3��(v �
�WFx�,���i����H]4�{~a��7&��]-��i��n=ٌyN�C��j?X�8��A��'�㤷��������{�(���G;�s5I�8�cQ|n������&�]�Y6,���6mo,�s��;�L�kĄkηn�u0Q����)��ȸ�( �<51��I���i�w�4u�(�mM/$J'�����$0n!5�*fWy�韼*�f/�s�6�%%ב�/9U�f�����X�(3�=E����=�$�X�Kv=���4y�N-��X�Y�lB�jm+vW:n�G�ȴ�D2�=ɰ�'l��� )7o3�����r��E�;"��`b��GњV��iRyiL��oU�[��1zAe���������aQPD���Fb�g��F���
��N{�P��	���7�S画�`J�����Q��4uӂvT�kˡ�@�w�s�*��x���d}�uem�ך^0��	������V��`�X*ù�t	/��]% G8r�{��}�|��3L�R��Xm�D��N���$��;���l�;�5��\zŁS$N�sd��m�i\;=M��V��Kw<
. OY�{|�ڞ�*M�2�s��I�����J���#�Χ�)A��WQ��� �Ru)� S��2m��\h���z�#�QD�y���GԠ�J1%q=&a��f)�`�c�:��8B���K�݆p�7n�j��^I���׉6Tp�1�Y-�^t���I�c]�|PApo~_��~T&8�����E�3�Tw�A#�Э�;#�R)7?zyȲ[c�<�J�l-�Q�O��<ڙ�׻?�q_���j���E�I��HDo��a�����g�-��*o�=���lbt	�#��K�U�.��yS��}=����9,}��sC�O�6�8�y�|�I�_��OV-�E�s�x�a��;'I�lF��-�֋��W��<�b���atJ*rk`,��`�^KZe,ּ���{�0��z�~���?�H�V��.�8,0�9�CKM��lG�@8�{��ҥ�~[?���t�����L�DY���+a�����uy��n�<K��
��q��J�Y���>���{��Z��:shZ�@�2�R�Iɹ[��e.]�ps����kFӶ+��l;�kx<P4f������ $2�ya�K�up��[gDQ�t�$�egd��ձo��V�*�LI�s�~9u8�-�A3�]�m������6<�����ŀW���_�����zk��ܮp_����G��'n����-�{�^��s�3����;��6�906v���^�ɓAj)r��m�^Y��VX�t���=9>�'-���%>���{_&�IG�Ә�XǶ��9K2�\V Mon�)�{
��{�W���l�?�F� ����ŔY��>���7�*��AG �~2ӈV-R����H�*HHG&&��� ��z*V'+h�kC˿Lx��v��9�,-���;1��%e��'��m��_.�ʬm�� ]�u�g8���o���$ �"��I�@%��^H�|;
C�,�����Y��Y��SՋ�yƺ�A�~򹱱�3"��z��֬Ub���໊@�\�]�Դ(���� i��M@�ߣ�7��vS���M���Kcqv݀To]ttv���UE��0�����NiO<���fW��Ys��r�k?�=�UZ���a�k�iU=@Å��%^�DU��t������]ӽ �_��`���
�C���f0��7���!��w��1���������IZU�kqE���8N@/t@�_p�6_��@����1O�r7�g�:H�����*���A�*���Fa�W�e��3�l�΢���s�gj��_����bD��k�>��bG�v� 1#�/�`҂��P��i`_$D�L�6]}x�#���i��6�[t4�x�����|ε��fT�S�@y��lD?��聑m��+k��~覃[蓛o��natk�g�&��N��'j>���(cϙ�4�y�0��1p�����d��d �� ��C<�'��n�#.EB�ǣvk6���L}��TUc�h�X�u��U%/��pO�7�H��@�/#��H�G$~� �ϙ�������]h��      l   �  xڕ�=r�7�k�.� �:Dn��3�"��uaB㙯�3;˂�eQ�a�5��b��H�ׄ=hH��S�����?���� ��d�p6���γ��̔�N�Qj�=:�LRP�s'5�6'O�����C5��� �C��ʕn�ޙ���т���5 yT�
�t:Z�wf��$<���5a��T�����u�V�f�Ď�鸽�����XQ8p��C�Њ�D�ъ{��J0��C�C�8$H��J+�T�h�C�4��534.�O�����վpu�T$Î�AqkE��*V���ʦ{VZߏ���M���z��-ܡ��5�t�P�mxE}�H�����W��zn��V�j�Ԛ����Pe�pu�P�xͤ��3�=2�9�Ԫ/~�������W��z����;/2ZԷ�^�אF�j���T��kK��l��Ȫ_S �h5!������Iu=�r��I��_��崂�0�5��TT�S;ZcGMͩ�:H�}Sc`kZy���k7�i�6x-��❼ڸjR��6��N'�I�Ӱr`�ŵUVbE]h8�C������[+v�,cv�δx!쨨��r�P�1�*Yl�Ph��Eo��{T=��J];Ĺǋ��#�ƴ|����hh��p����=�n��[�z��<���������� �'      m   ?  xڥ�ێ����O���åsB�Ycmlnr�CqF��4�4v��S�/��@�
!["1��~��E6�]H!�hf�b���:� m6�J�i�'|��_���
�:���V ܤ�
��L��]�J�F��_��~�=��w'8���a����EV	��������|�Y@���v��.U���m"9�(�&��1��6��JH�����Kc�m�9�Fܦ�d�
�m 
N$���=j3���4r�Q��MQ)B��xn���V�n�|S]jщ�i䠄q��d,�I�*,��q��z;Я���M"KiSq���⍒4��'nW'��S��ܸM$��G�6M�+�xq�ƭ�UNܮ���To=�o�Y������t�E$��۠R�!h57$���#nU"��r���p��!��m�h�㎒Drf$�U ,/'!q���qFɦdt�K�����n�Ue�4-��E7�\��v��K��Z�n����0�6M%��xn�Q]'����,]j�;�����m$�U�0�6�B���o�����K�� ��}{$nSUbˬ�ƕ�ǳܖR��;R���HB$+r '��d�Y�"wY)��I��m�T�;��$2��"��MS�29����+�:	��5t�#�mY�f�T�`�a�M�[T���6IK�u�F�XG"	M%���m
WKc=�ok)d1]j(�n�%��������Q�ƍ)��q;:'T����^���M��D�Po��p� �یU�,j3Jt��q�m*�6���D��{��?�M�J-�gd�Y�"{�	��s�&P�IV7�6Qo���%��q;�S��+��4��!��MSI�m
�Aq�1J���^�&wvC%�I�&��`y������%3���R3{�Hv"������<o�N�fWg��Y����sI*�9��4���g�M�6�%g��M���Ԭ-�o�� ���MQ	B�M<�I\�k�D�` ��Rq0��m"�� i*���%i�$L�c�mC���(I$��F"	Q�U�^)7b�׷[�&�T_3pݦ��5#9	ME�Xy���u'nG'}�J>~���\�"�=�i$'!�8Ux �[���'�x´���hc�M#��:2J�T����6����,�����.���%id-���D�e��m��8�dʩv��Tl����p�Fν���I*UB��$$n���~<@ݧ֪��6��%9��JU	X+�4n�.pv��J�>55v�&��(#�6MEi%YWʈ\�s2�bS��jqX��m"��Ȏb�J���6����,���4�J�Z�ݦ�[���T����~r�­�D�*d�]��/����nhd�t��D�/�r7+��s�N���x@j(��o���nh*�w;��nS��e˜H����T��o���&�T�ҙ7s�qS��n ��m� e�u�Dκ]�$���ۙF�.�%p�v3ɗ���,�C�5@"�e1I�*YW� ��;N$i{��A��<�m�ay$�&��dx��)܂�����v�фČ�Tr�n��;Q%	�X}���Rp܆P{ye�͸P�n�ȱ�앢���m
��Թ]���5����'zw��6����HBU)Ƴr"7˦��T �.����Dr�m�m�J����6�k���1�)V�]��e�n�d��d�D�\ee�Dn��3~p;��v��qz �n�ȱ呸MRq�=�L�I\/�ބ�\u�t�V[�uI*9�8�*EU)E��6��sɜ����R��E	� T2�#}��R��e�$��°2@/0�U]*�PܾM$���$U%G�\�ȵAs�����Х���$�3zdG1U%��k���r܆�j�1P���wC%/gp��R-�ܦp1�s���Pњ.55��I���@�MTi���M�q��.3�v5�uW�O�Q�J�ud?	Q�Y9	��eT5k�\r9 �ۗ��ֆ�H&�޳�n�MVA�8�$����<����qw�r�S�;����sNz��U�ɢE��#>�P���<�e����h����/���ݷ{8�t��|-n~'J	���;��x�rޗ��{Jw0=��浶�Ӆ!��=��O��W�};>&lֵ2_+捬��e��ۭ����a��ҵ?m�a#��$����L��ͽ��:�;Q�un�����J:��K�Z��(4]Pv�U�<�v�����kyӎ
1����3-�|z��s<�t��|-��d4%��������Ӯ����gZ�����bm�!�d��<^����y_1�����Z�t&� ��dE/��ty�p���O��t���k�m(�f�t�dobW�_��9=���{qc��x�����ò����w�\?6]�:��Q(�кKH��tz�=�	S��ڼ�6��0�,l���?�]y~�x�2=,�k�R۴��w�/�*w�o�u���05���S��1���Y���/���ڎ8��̯�M�z���[J�6����^�[�'��R���M�,���:�~L������;��2�cu��|�nN���KSn��1}��v�C��0��2_��ke󋣖�އ+�����?�×�%���Lk�Z�����{+�΂��姭��m�58�k����}s���a}w�Ǆ��y�̯��.��_�s���VO/��×����k���F�h�'N�uR�?��$���݈E�ɿ2Ke;;��iIV��Oߖ�7��ǐl�qe�����h������3�h�=������R���ty�܊� �yN����~�����=N�X��Ҧ��"��&��v�OO�=6"�`J����7��K����I�?>`΃������R�_+o�\L����:�{�}�%�V�*�浴JX����3/����yI�/h�R���&�9�if�;7�|�t>��'��y��߫�δ>��&��?�{��n	0      r   �  xڭ�Kr 7��3��>e�xAΒ���?B����")�z���|��� �h̥�����@o�}|pH��v�?0 ~@� �� �}�h�����c��I����f�dT)����Q���8ƛ�tK�
q��K��t�XY��<V,)�P
��[��+��Z�����x��_!�w�I,�P�M�oXI� ��!�� �qdd�'FE���k-�bRK+��4R9 f���8i��kL5ʊX��*�Ĥ�}��c��X���
�J�}E\�q�8	�yR����]�J�$�6�6��UB��XZ�Q_!n ��2˾�Y�n�0S�*�U^I��HV�������b(���	��J����#�X�&f-c%\�N�]E^�Fq��I����V$A�
q��K?����V���A�q�^E�G0���GIS_f�T�c�'N�c��b�g����E�"�b�3C��u�����:k�qM����b<�
c�'�:x����V��<m���g
�+4�Ur`�-/�m��WZ���>1$����+�
`�$�����%�_�|��4鬏)'{�"�*��yNb�t������N�޴�﻿�Į+�X����)�]&v����F;<����� N�:����m��U��So�@�cd����ƞ��ټ���4q�h��.M��Z���9��M�+屓8s�b� vz��x9!��=m�ؗ�]�%g=�<�F��`�4�� +�t'i��Y�hm:���A�M_H�O�<'�(���_�:�~�ƾ����Eu�MÆ�]��$νd#��&������u�݈<_y�$��"���7�]զ�xH��~���F������Z ���x`��}7 H�1S�%�L� ,�q��8��������E��~��쟂8��31l��+P,�b_�vS�t �!>���ҢE��c��Ƙm������N�L|y4Em�ةn>�Qҁ�y�ac_q�8�@+���$�!�]A|���tB�h�+|z�"���Woz�ا�>�TꁍcH[Z�ۮ���zId#��E�\�n �_n��}6����XǁW�%��9i����2����Z<Ęg~#K��s�-!HdO}�!v��}��W��ȸacW]�$����&�6���]�5@8��'���>�/K��A�I���3A��}g�y�A�Փ9:��3�u���GܡLL��?�p����*���������q�Z�N�J�c0ذ�O+<�9,���E�ٹ�{vn2\;��Ĉ��@��}u�����+��ix{���~�����AA�Y�n�5��
1�8��!���Cܻ�W�
�B9�c��A��y>��ǉ�52o�r���IN����6�}���x�j�bK
�m7�k�-Ǿh��?q���}3�K�_y��!.��m���g�}o��K[�_�ϓ��"K�<t�X���*b���6����r=�X����ַ�-$��8�e۲J�������ȋ���'�R�ys�o�xʀR_kO���&1�_So焼���]�e�y���m��W�.e9�?.B�xEl۾W0����K7^ls9m�#�9�S��d)g�R贱��W4Ah�^!较�3�������~*�X��x��]^�"�*8��S�x���#B^�L}6�#��R{�ԓ�O�	n�Y�ab�����g�� }��_	�� cx� 6�'f��[��7v�Zl��X7��� |��b�)��W���<�Gh_D�ԀFٿN
�x ��t��<��kZt<�ĝq5�4o����O|��<A¢9�����
��W ����Cz�%R]�R��M�wVA�s��LyaE���u`��ſ��v�YWj�;�X�~�!����\`u�w��.����pO`�������=q�S_uH�K���#�}��G,���k�n�Q��ie�n<R�&���~XQ�^w���^����&��6%��3�#Hr3az��G�4��IS�\���FI��<qCIa��K\rɸǑ���<�⥃�zZ��4.�?���j���      q   9  xڭ��Nk7��ûP�0�_��T�|�aIh�S��;YNo�%{-� A@,����� �`�)�P}~ֺ�g�R�Ae,v����}����xڅ�O���ܗ�������#���N#�&2ޓs�xw�!;o��ß�b�S	�Q#��� %�K�b9�w�������r�B��wu5D�
j�l }�!��0"��en(x� ��85 @eb�����}��a�*�#�LXIB�"j�G�RLS	�m?2-{�����x�Ư�c�jj1bq�SKF�j2`�f��ȵ������-#�3�2"�Y����x�P�t�$�� �Ov��]�!�\�F��\#$]
��`F����~2����bK��{d�RҬ���?*=�Iұ�I��@��HZ'�g2i��^�v!��/F�� �u�ް1-#�f�F=��x55#�e�4����`$S��f�o�׷s��-#�Ax�2�YZ�#�ʰKQ�.O��<z���~��	��r�����??��IڳیX��T��2���!�C�b��K���##rHyLP
�MF�I�O�>���U���y{�U�!��!C-.�J� U}*�M����fH`X�����P�N���Դ"���=B��A���.����cD_��P ���#�p,��1D(یثzuЇ�7��� �0Qgd
�͈�N�p�֩#}}U]od�^dX��:3���p�*�p�,�(��M2�n��m߃ y�ݳ����.{6� �:F_%�FY��d���n�a��k �zn4����28�ՌU�J��[�)zQ�c���R�7q=����A�.#�A0'��l�r�!�k��P��9��A_N�ЍGY�Q�"��d2��&� _-��W��J�4"(I�J���mE�Ġ_'yD��J����Ԝ#����.e�LMwy�5�,�*S	�6�.�ۓҤF�ߖ��-�.�����ae(8Va�*�q���>��xhk���43����d��H��1�m�m���?z �]�VAd�-�����!���-�o(�b�ն�a�F�#u!@�^��5������/��	�      e   0  xڥ��n�8�׮�в
�L�~�e70�^�r6Eي-�e;��ϡl�N�i)� �@<���\��Z�E�4"�Hk_"���2�]�sST��>;V�j۝��画�l����&t���ĭ[�Ŕ"�1!�0��̋��a�4
��J*C�����oR�\0=C�w�ֻ�$�;xd��YՔ��������sCwn���ћY�r�뗜�4����h���j��������*��6�ۮ�]�Q~�F�4����ͺZ���5��&�����Y��΁��������M�zȰ������9�Y�P��:İ��Н�w����n>V2�_�4�ь�1j��$!����V5M{�=O��!j���fD���~}�+�P��D�$J�������Caڨ�	X5�7 ���ٟ���|7D�΀r��� ��;��D�i�N��f�(>c��>o���b  �z��\v�űW��j@�1�ޥ8�&I ��!(8sB�hY?_*e��Y�-̇���UH��ъ�Vۼ��7k- cXEB�M�l���.����b�ʑ������&j���z�/K*�Z�,�ti��}�Q[���0jj�w���]}�AW�mJ̎��hZ�\��ǐ,�*�'�+|ݵ��4	#�p~� aB���$f�6��P��10�q�� E�{N���n~�9�M�R���nӴ�v]�!0Wt��} 0���r�=Tn��,�e(Č�Y��
���Vv������uv��mg�j]��4Yк�&�]�
�tBH"�������+x%��t��y7﷮��ٴvލ��n��#VU�
J%����/������BI��\��.8�C���..��?·M��L��t�c�hR��9�;�tt��][�{�c����O��ݧ�@���	MN�o{�݇]�S'Փ��(%��|-$s���d���r�<�m���d0}j�	��;U<�Ռ&��T�bT�5l���x����mj�m3_���`���9���dF�]ͱP`{*Eb�1ڤ�H?t*�e0��y+������ kع�ݺ
=,b�����|>� D�M�y��s��1�F<�Xac�����њC��@a��Ulr-�/����n�R�X��nN����Ft�!2�ۢ��5~��[��S���o���v� ��Wn8@�*�ۣ�+�@�n�7���S��O�4������dlq��s�ŷ?��
f�a�i,�f��G�,P�㞢S�D��;���b�u[�L�E�d��Z�����(೿��>^���ʏ��`�j�W~4%��W.�c������2���[��G��3�')�xa_3�4KTp_����,�[FcT�+b��9��kIV��̔���aK���u���#;l)���l�[^ht�
�؍�����]X��a���,bb\f�q�R@��p]�fW�u>�M���~h��'�c��ac/
6%R|JSr)��q+5��_�W5��'H!�C�'\wvߖ��Q`��3-Oj&�4_!t�������)��l�l��#��	,g�6o�������n}�^>IC�9L�vN��t�[�)�A�Y���v����?�i�~5��	^��9��k��(.�Z����,���@�OM�a�@�|�U�S0SB�0bB�DÈ*����͐�1������?�BB.�X�仏V��b�1��+�]ۇ�-�q��C�w�i�����o��M�EG���e�r/��rx����m��8���ǣ����vE������Y�u]vcz(�S���`���&������V��N�x�7���'T��#��T�0����\������۷�T�mq     