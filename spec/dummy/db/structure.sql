SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: count_estimate(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_estimate(query text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
      DECLARE
          rec   record;
          ROWS  INTEGER;
      BEGIN
          FOR rec IN EXECUTE 'EXPLAIN ' || query LOOP
              ROWS := SUBSTRING(rec."QUERY PLAN" FROM ' rows=([[:digit:]]+)');
              EXIT WHEN ROWS IS NOT NULL;
          END LOOP;

          RETURN ROWS;
      END
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agent_api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_api_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token character varying NOT NULL,
    name character varying,
    last_used_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp without time zone,
    expires_at timestamp without time zone
);


--
-- Name: agent_api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_api_tokens_id_seq OWNED BY public.agent_api_tokens.id;


--
-- Name: agent_approval_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_approval_grants (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    tool character varying NOT NULL,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    tool_call_id character varying,
    expires_at timestamp without time zone NOT NULL,
    consumed_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agent_approval_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_approval_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_approval_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_approval_grants_id_seq OWNED BY public.agent_approval_grants.id;


--
-- Name: agent_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_conversations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying,
    approval_mode character varying DEFAULT 'confirm_writes'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status character varying DEFAULT 'idle'::character varying NOT NULL,
    running_started_at timestamp without time zone
);


--
-- Name: agent_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_conversations_id_seq OWNED BY public.agent_conversations.id;


--
-- Name: agent_knowledge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_knowledge (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value text NOT NULL,
    category character varying NOT NULL,
    scope character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agent_knowledge_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_knowledge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_knowledge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_knowledge_id_seq OWNED BY public.agent_knowledge.id;


--
-- Name: agent_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_messages (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    role character varying NOT NULL,
    content text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    rating character varying
);


--
-- Name: agent_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_messages_id_seq OWNED BY public.agent_messages.id;


--
-- Name: agent_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_skills (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text NOT NULL,
    instructions text NOT NULL,
    usage_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tool_sequence jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_by bigint
);


--
-- Name: agent_skills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_skills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_skills_id_seq OWNED BY public.agent_skills.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: grid_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grid_states (
    id integer NOT NULL,
    user_id integer,
    name character varying DEFAULT 'default'::character varying,
    grid_name character varying,
    state_value text,
    current boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: grid_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grid_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grid_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grid_states_id_seq OWNED BY public.grid_states.id;


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id integer NOT NULL,
    first_name character varying,
    last_name character varying,
    birthdate timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    job character varying,
    vip boolean DEFAULT false,
    age integer DEFAULT 18,
    signature text,
    status integer DEFAULT 0,
    country_id integer,
    training_id integer
);


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.people_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.people_id_seq OWNED BY public.people.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description character varying
);


--
-- Name: permissions_privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions_privileges (
    id bigint NOT NULL,
    permission_id integer,
    privilege_id integer
);


--
-- Name: privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privileges (
    id bigint NOT NULL,
    name character varying,
    description character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text
);


--
-- Name: roles_privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles_privileges (
    id bigint NOT NULL,
    role_id integer,
    privilege_id integer
);


--
-- Name: roles_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles_users (
    id integer NOT NULL,
    user_id integer,
    role_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users_privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_privileges (
    id bigint NOT NULL,
    user_id integer,
    privilege_id integer
);


--
-- Name: permission_all_users; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.permission_all_users AS
 SELECT concat(permission_id, '-', user_id, '-', source_type) AS id,
    permission_id,
    permission_name,
    permission_description,
    user_id,
    source_type,
    source_name
   FROM ( SELECT DISTINCT p.id AS permission_id,
            p.name AS permission_name,
            p.description AS permission_description,
            ru.user_id,
            'role'::text AS source_type,
            r.name AS source_name
           FROM ((((public.roles_users ru
             JOIN public.roles_privileges rp ON ((rp.role_id = ru.role_id)))
             JOIN public.permissions_privileges pp ON ((pp.privilege_id = rp.privilege_id)))
             JOIN public.permissions p ON ((p.id = pp.permission_id)))
             JOIN public.roles r ON ((r.id = ru.role_id)))
        UNION
         SELECT DISTINCT p.id AS permission_id,
            p.name AS permission_name,
            p.description AS permission_description,
            up.user_id,
            'privilege'::text AS source_type,
            priv.name AS source_name
           FROM (((public.users_privileges up
             JOIN public.permissions_privileges pp ON ((pp.privilege_id = up.privilege_id)))
             JOIN public.permissions p ON ((p.id = pp.permission_id)))
             JOIN public.privileges priv ON ((priv.id = up.privilege_id)))) subquery
  ORDER BY permission_name, user_id;


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: permissions_privileges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_privileges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_privileges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_privileges_id_seq OWNED BY public.permissions_privileges.id;


--
-- Name: permissions_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions_roles (
    id integer NOT NULL,
    permission_id integer,
    role_id integer
);


--
-- Name: permissions_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_roles_id_seq OWNED BY public.permissions_roles.id;


--
-- Name: privileges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.privileges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privileges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.privileges_id_seq OWNED BY public.privileges.id;


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: roles_privileges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_privileges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_privileges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_privileges_id_seq OWNED BY public.roles_privileges.id;


--
-- Name: roles_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_users_id_seq OWNED BY public.roles_users.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: user_all_permissions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_all_permissions AS
 SELECT concat(user_id, '-', permission_id, '-', source_type) AS id,
    user_id,
    permission_id,
    permission_name,
    permission_description,
    source_type,
    source_name
   FROM ( SELECT DISTINCT ru.user_id,
            p.id AS permission_id,
            p.name AS permission_name,
            p.description AS permission_description,
            'role'::text AS source_type,
            r.name AS source_name
           FROM ((((public.roles_users ru
             JOIN public.roles_privileges rp ON ((rp.role_id = ru.role_id)))
             JOIN public.permissions_privileges pp ON ((pp.privilege_id = rp.privilege_id)))
             JOIN public.permissions p ON ((p.id = pp.permission_id)))
             JOIN public.roles r ON ((r.id = ru.role_id)))
        UNION
         SELECT DISTINCT up.user_id,
            p.id AS permission_id,
            p.name AS permission_name,
            p.description AS permission_description,
            'privilege'::text AS source_type,
            priv.name AS source_name
           FROM (((public.users_privileges up
             JOIN public.permissions_privileges pp ON ((pp.privilege_id = up.privilege_id)))
             JOIN public.permissions p ON ((p.id = pp.permission_id)))
             JOIN public.privileges priv ON ((priv.id = up.privilege_id)))) subquery
  ORDER BY user_id, permission_name;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_preferences_id_seq OWNED BY public.user_preferences.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_privileges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_privileges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_privileges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_privileges_id_seq OWNED BY public.users_privileges.id;


--
-- Name: agent_api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_tokens ALTER COLUMN id SET DEFAULT nextval('public.agent_api_tokens_id_seq'::regclass);


--
-- Name: agent_approval_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_approval_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_approval_grants_id_seq'::regclass);


--
-- Name: agent_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_conversations ALTER COLUMN id SET DEFAULT nextval('public.agent_conversations_id_seq'::regclass);


--
-- Name: agent_knowledge id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge ALTER COLUMN id SET DEFAULT nextval('public.agent_knowledge_id_seq'::regclass);


--
-- Name: agent_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages ALTER COLUMN id SET DEFAULT nextval('public.agent_messages_id_seq'::regclass);


--
-- Name: agent_skills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_skills ALTER COLUMN id SET DEFAULT nextval('public.agent_skills_id_seq'::regclass);


--
-- Name: grid_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_states ALTER COLUMN id SET DEFAULT nextval('public.grid_states_id_seq'::regclass);


--
-- Name: people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people ALTER COLUMN id SET DEFAULT nextval('public.people_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: permissions_privileges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions_privileges ALTER COLUMN id SET DEFAULT nextval('public.permissions_privileges_id_seq'::regclass);


--
-- Name: permissions_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions_roles ALTER COLUMN id SET DEFAULT nextval('public.permissions_roles_id_seq'::regclass);


--
-- Name: privileges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privileges ALTER COLUMN id SET DEFAULT nextval('public.privileges_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: roles_privileges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles_privileges ALTER COLUMN id SET DEFAULT nextval('public.roles_privileges_id_seq'::regclass);


--
-- Name: roles_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles_users ALTER COLUMN id SET DEFAULT nextval('public.roles_users_id_seq'::regclass);


--
-- Name: user_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences ALTER COLUMN id SET DEFAULT nextval('public.user_preferences_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_privileges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_privileges ALTER COLUMN id SET DEFAULT nextval('public.users_privileges_id_seq'::regclass);


--
-- Name: agent_api_tokens agent_api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_tokens
    ADD CONSTRAINT agent_api_tokens_pkey PRIMARY KEY (id);


--
-- Name: agent_approval_grants agent_approval_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_approval_grants
    ADD CONSTRAINT agent_approval_grants_pkey PRIMARY KEY (id);


--
-- Name: agent_conversations agent_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_conversations
    ADD CONSTRAINT agent_conversations_pkey PRIMARY KEY (id);


--
-- Name: agent_knowledge agent_knowledge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge
    ADD CONSTRAINT agent_knowledge_pkey PRIMARY KEY (id);


--
-- Name: agent_messages agent_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages
    ADD CONSTRAINT agent_messages_pkey PRIMARY KEY (id);


--
-- Name: agent_skills agent_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_skills
    ADD CONSTRAINT agent_skills_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: grid_states grid_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_states
    ADD CONSTRAINT grid_states_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: permissions_privileges permissions_privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions_privileges
    ADD CONSTRAINT permissions_privileges_pkey PRIMARY KEY (id);


--
-- Name: permissions_roles permissions_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions_roles
    ADD CONSTRAINT permissions_roles_pkey PRIMARY KEY (id);


--
-- Name: privileges privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privileges
    ADD CONSTRAINT privileges_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: roles_privileges roles_privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles_privileges
    ADD CONSTRAINT roles_privileges_pkey PRIMARY KEY (id);


--
-- Name: roles_users roles_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles_users
    ADD CONSTRAINT roles_users_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_privileges users_privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_privileges
    ADD CONSTRAINT users_privileges_pkey PRIMARY KEY (id);


--
-- Name: index_agent_api_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_api_tokens_on_token ON public.agent_api_tokens USING btree (token);


--
-- Name: index_agent_api_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_api_tokens_on_user_id ON public.agent_api_tokens USING btree (user_id);


--
-- Name: index_agent_approval_grants_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_approval_grants_on_expires_at ON public.agent_approval_grants USING btree (expires_at);


--
-- Name: index_agent_approval_grants_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_approval_grants_on_token_digest ON public.agent_approval_grants USING btree (token_digest);


--
-- Name: index_agent_approval_grants_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_approval_grants_on_user_id ON public.agent_approval_grants USING btree (user_id);


--
-- Name: index_agent_conversations_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_conversations_on_status ON public.agent_conversations USING btree (status);


--
-- Name: index_agent_conversations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_conversations_on_user_id ON public.agent_conversations USING btree (user_id);


--
-- Name: index_agent_conversations_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_conversations_on_user_id_and_updated_at ON public.agent_conversations USING btree (user_id, updated_at);


--
-- Name: index_agent_knowledge_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_knowledge_on_category ON public.agent_knowledge USING btree (category);


--
-- Name: index_agent_knowledge_on_key_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_knowledge_on_key_and_scope ON public.agent_knowledge USING btree (key, COALESCE(scope, ''::character varying));


--
-- Name: index_agent_knowledge_on_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_knowledge_on_scope ON public.agent_knowledge USING btree (scope);


--
-- Name: index_agent_messages_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_messages_on_conversation_id ON public.agent_messages USING btree (conversation_id);


--
-- Name: index_agent_messages_on_conversation_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_messages_on_conversation_id_and_created_at ON public.agent_messages USING btree (conversation_id, created_at);


--
-- Name: index_agent_skills_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_skills_on_name ON public.agent_skills USING btree (name);


--
-- Name: index_grid_states_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grid_states_on_user_id ON public.grid_states USING btree (user_id);


--
-- Name: index_people_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_country_id ON public.people USING btree (country_id);


--
-- Name: index_people_on_training_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_training_id ON public.people USING btree (training_id);


--
-- Name: index_user_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_preferences_on_user_id ON public.user_preferences USING btree (user_id);


--
-- Name: index_user_preferences_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_preferences_on_user_id_and_name ON public.user_preferences USING btree (user_id, name);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: uniq_permissions_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_permissions_name ON public.permissions USING btree (name);


--
-- Name: agent_messages fk_rails_d86808b0c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages
    ADD CONSTRAINT fk_rails_d86808b0c3 FOREIGN KEY (conversation_id) REFERENCES public.agent_conversations(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261008065342'),
('20260821120000'),
('20260721082348'),
('20260630120000'),
('20260629120000'),
('20260627120000'),
('20260626120100'),
('20260626120000'),
('20260625120000'),
('20260623120000'),
('20260622000000'),
('20260616120001'),
('20260616120000'),
('20260611150000'),
('20260318000000'),
('20251126000000'),
('20250930152629'),
('20230908073615'),
('20210615142410'),
('20200601022655'),
('20200522032554'),
('20200520085806'),
('20200427132713'),
('20171020160100'),
('20170301095901'),
('20161228180000'),
('20111206070528');

