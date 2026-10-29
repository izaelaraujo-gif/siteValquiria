-- Cole tudo em Supabase > SQL Editor > Run.
-- Pode rodar mesmo se você já rodou a versão anterior: ele só atualiza o que mudou.

create table if not exists servicos(id bigint generated always as identity primary key, grupo text not null, tamanho text default '', preco numeric, obs text default '', ativo boolean default true, ordem int default 0);
create table if not exists clientes(id bigint generated always as identity primary key, nome text not null, whatsapp text unique not null, created_at timestamptz default now());
create table if not exists agendamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete cascade, servico text not null, data date not null, hora text not null, status text default 'agendado', created_at timestamptz default now());
create table if not exists lancamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete set null, tipo text not null check (tipo in ('entrada','saida')), descricao text, valor numeric not null, pago boolean default true, data date default current_date);
create table if not exists orcamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete cascade, descricao text, valor numeric not null, status text default 'aberto', created_at timestamptz default now());
create table if not exists fotos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete cascade, path text not null, legenda text default '', created_at timestamptz default now());

alter table servicos enable row level security;
alter table clientes enable row level security;
alter table agendamentos enable row level security;
alter table lancamentos enable row level security;
alter table orcamentos enable row level security;
alter table fotos enable row level security;

-- Visitantes só leem os procedimentos. Só a Valquíria (logada) acessa o resto.
drop policy if exists "ver servicos" on servicos;
drop policy if exists "adm servicos" on servicos;
drop policy if exists "adm clientes" on clientes;
drop policy if exists "adm agendamentos" on agendamentos;
drop policy if exists "adm lancamentos" on lancamentos;
drop policy if exists "adm orcamentos" on orcamentos;
drop policy if exists "adm fotos" on fotos;
create policy "ver servicos" on servicos for select using (true);
create policy "adm servicos" on servicos for all to authenticated using (true) with check (true);
create policy "adm clientes" on clientes for all to authenticated using (true) with check (true);
create policy "adm agendamentos" on agendamentos for all to authenticated using (true) with check (true);
create policy "adm lancamentos" on lancamentos for all to authenticated using (true) with check (true);
create policy "adm orcamentos" on orcamentos for all to authenticated using (true) with check (true);
create policy "adm fotos" on fotos for all to authenticated using (true) with check (true);

-- O agendamento pelo site foi retirado: as clientes não escrevem mais no banco.
drop function if exists agendar(text,text,text,date,text);
drop function if exists horarios_ocupados(date);

-- Pasta privada das fotos dos cabelos (só a Valquíria logada acessa)
insert into storage.buckets(id,name,public) values ('fotos-clientes','fotos-clientes',false) on conflict (id) do nothing;
drop policy if exists "adm fotos storage" on storage.objects;
create policy "adm fotos storage" on storage.objects for all to authenticated
  using (bucket_id='fotos-clientes') with check (bucket_id='fotos-clientes');

-- Procedimentos iniciais (só entram se a tabela estiver vazia)
insert into servicos(grupo,tamanho,preco,obs,ordem)
select * from (values
('Botox','Curto',110,'',1),('Botox','Médio',160,'',1),('Botox','Longo',190,'',1),
('Progressiva','Curto',130,'',2),('Progressiva','Médio',170,'',2),('Progressiva','Longo',210,'a partir de',2),('Progressiva','Extra longo',null,'sob consulta',2),
('Tintura + Escova','Curto',65,'',3),('Tintura + Escova','Médio',75,'',3),('Tintura + Escova','Longo',100,'',3),
('Escova + Chapinha','Curto',40,'',4),('Escova + Chapinha','Médio',50,'',4),('Escova + Chapinha','Longo',70,'',4),
('Hidratação + Escova','Curto',45,'',5),('Hidratação + Escova','Médio',65,'',5),('Hidratação + Escova','Longo',90,'',5),
('Cronograma Capilar (3 sessões)','Curto',105,'',6),('Cronograma Capilar (3 sessões)','Médio',180,'',6),('Cronograma Capilar (3 sessões)','Longo',240,'',6),
('Aplicação de tintura','',25,'a partir de',7),('Corte','',30,'',8)
) as v(grupo,tamanho,preco,obs,ordem)
where not exists (select 1 from servicos);

-- Fotos que a Valquíria marcar como "Mostrar no site" aparecem para os visitantes
alter table fotos add column if not exists publica boolean default false;
drop policy if exists "ver fotos publicas" on fotos;
create policy "ver fotos publicas" on fotos for select to anon using (publica = true);
drop policy if exists "ver galeria" on storage.objects;
create policy "ver galeria" on storage.objects for select to anon
  using (bucket_id='fotos-clientes' and exists (select 1 from public.fotos f where f.path = name and f.publica = true));
