--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6 (Debian 17.6-1)
-- Dumped by pg_dump version 17.6 (Debian 17.6-1)

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: kyc_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.kyc_status AS ENUM (
    'UNVERIFIED',
    'PENDING',
    'VERIFIED',
    'REJECTED'
);


ALTER TYPE public.kyc_status OWNER TO postgres;

--
-- Name: trade_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.trade_type AS ENUM (
    'BUY',
    'SELL',
    'AUTO_CONVERT'
);


ALTER TYPE public.trade_type OWNER TO postgres;

--
-- Name: trx_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.trx_status AS ENUM (
    'PENDING',
    'SUCCESS',
    'FAILED',
    'REVERSED'
);


ALTER TYPE public.trx_status OWNER TO postgres;

--
-- Name: wallet_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.wallet_type AS ENUM (
    'FIAT',
    'CRYPTO'
);


ALTER TYPE public.wallet_type OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: crypto_wallets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crypto_wallets (
    id integer NOT NULL,
    user_id integer,
    symbol character varying(10) NOT NULL,
    address character varying(100),
    balance numeric(20,8) DEFAULT 0.0
);


ALTER TABLE public.crypto_wallets OWNER TO postgres;

--
-- Name: crypto_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crypto_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crypto_wallets_id_seq OWNER TO postgres;

--
-- Name: crypto_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.crypto_wallets_id_seq OWNED BY public.crypto_wallets.id;


--
-- Name: fiat_wallets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fiat_wallets (
    id integer NOT NULL,
    user_id integer,
    currency character varying(3) DEFAULT 'IDR'::character varying,
    balance numeric(15,2) DEFAULT 0.00
);


ALTER TABLE public.fiat_wallets OWNER TO postgres;

--
-- Name: fiat_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fiat_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fiat_wallets_id_seq OWNER TO postgres;

--
-- Name: fiat_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fiat_wallets_id_seq OWNED BY public.fiat_wallets.id;


--
-- Name: merchants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.merchants (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    city character varying(50)
);


ALTER TABLE public.merchants OWNER TO postgres;

--
-- Name: merchants_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.merchants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.merchants_id_seq OWNER TO postgres;

--
-- Name: merchants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.merchants_id_seq OWNED BY public.merchants.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    user_id integer,
    merchant_id integer,
    amount numeric(15,2) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying,
    conversion_trade_id integer,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    note text
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactions (
    id integer NOT NULL,
    amount numeric
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactions_id_seq OWNER TO postgres;

--
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    kyc_level character varying(20) DEFAULT 'UNVERIFIED'::character varying,
    role character varying(20) DEFAULT 'USER'::character varying,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: crypto_wallets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets ALTER COLUMN id SET DEFAULT nextval('public.crypto_wallets_id_seq'::regclass);


--
-- Name: fiat_wallets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fiat_wallets ALTER COLUMN id SET DEFAULT nextval('public.fiat_wallets_id_seq'::regclass);


--
-- Name: merchants id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.merchants ALTER COLUMN id SET DEFAULT nextval('public.merchants_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: crypto_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_wallets (id, user_id, symbol, address, balance) FROM stdin;
4	1	ETH	0xUserSatuETH123	0.50000000
3	2	BTC	bc1qBitcoinWaLLeT98765	0.00066667
2	2	SOL	SoLaNaWaLLeTDzXy12345	0.25000000
1	2	ETH	0xSultanWallet123	0.00000001
\.


--
-- Data for Name: fiat_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fiat_wallets (id, user_id, currency_code, balance) FROM stdin;
1	1	IDR	9850000.00
2	2	IDR	0.00
\.


--
-- Data for Name: merchants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.merchants (id, name, city) FROM stdin;
1	Toko Simpel	Jakarta
300001	Merchant 300001	Unknown City
300004	Merchant 300004	Unknown
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, user_id, merchant_id, amount, status, conversion_trade_id, description, created_at, note) FROM stdin;
1	1	1	100000.00	SUCCESS	\N		2025-12-30 02:07:27.402118+07	\N
6	1	300001	25000.00	SUCCESS	\N		2025-12-30 03:07:05.090206+07	\N
7	1	300001	25000.00	SUCCESS	\N		2025-12-30 03:17:08.034346+07	\N
8	2	300001	25000.00	SUCCESS	\N	\N	2025-12-30 08:54:50.765515+07	 | Source: HYBRID (FIAT + ETH). Auto-converted 0.000833 ETH
9	2	300001	25000.00	SUCCESS	\N	\N	2025-12-30 10:41:03.227053+07	 | Source: HYBRID (FIAT + ETH). Auto-converted 0.000833 ETH
10	2	300004	100000.00	SUCCESS	\N	\N	2025-12-31 00:28:50.79969+07	 | Source: HYBRID (FIAT + ETH). Auto-converted 0.003333 ETH
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (id, amount) FROM stdin;
1	150000
2	20000
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, full_name, email, password_hash, kyc_level, role, created_at) FROM stdin;
1	Sultan Demo	demo@qryptopay.com	hash123	VERIFIED	USER	2025-12-30 01:47:39.821103+07
2	Sultan Kripto	sultan@crypto.com	123456	VERIFIED	USER	2025-12-30 03:25:49.727038+07
\.


--
-- Name: crypto_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_wallets_id_seq', 4, true);


--
-- Name: fiat_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fiat_wallets_id_seq', 2, true);


--
-- Name: merchants_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.merchants_id_seq', 1, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 10, true);


--
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 2, true);


--
-- Name: crypto_wallets crypto_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_pkey PRIMARY KEY (id);


--
-- Name: fiat_wallets fiat_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fiat_wallets
    ADD CONSTRAINT fiat_wallets_pkey PRIMARY KEY (id);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: crypto_wallets unique_crypto_wallet; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT unique_crypto_wallet UNIQUE (user_id, symbol);


--
-- Name: fiat_wallets unique_fiat_wallet; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fiat_wallets
    ADD CONSTRAINT unique_fiat_wallet UNIQUE (user_id, currency_code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: crypto_wallets crypto_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: fiat_wallets fiat_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fiat_wallets
    ADD CONSTRAINT fiat_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_merchant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

