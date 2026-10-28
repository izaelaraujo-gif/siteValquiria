-- Cole tudo isto em Supabase > SQL Editor > Run

create table servicos(id bigint generated always as identity primary key, grupo text not null, tamanho text default '', preco numeric, obs text default '', ativo boolean default true, ordem int default 0);
create table clientes(id bigint generated always as identity primary key, nome text not null, whatsapp text unique not null, created_at timestamptz default now());
create table agendamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete cascade, servico text not null, data date not null, hora text not null, status text default 'agendado', created_at timestamptz default now());
create table lancamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete set null, tipo text not null check (tipo in ('entrada','saida')), descricao text, valor numeric not null, pago boolean default true, data date default current_date);
create table orcamentos(id bigint generated always as identity primary key, cliente_id bigint references clientes on delete cascade, descricao text, valor numeric not null, status text default 'aberto', created_at timestamptz default now());

alter table servicos enable row level security;
alter table clientes enable row level security;
alter table agendamentos enable row level security;
alter table lancamentos enable row level security;
alter table orcamentos enable row level security;

-- Visitantes só leem os procedimentos. Só a Valquíria (logada) acessa o resto.
create policy "ver servicos" on servicos for select using (true);
create policy "adm servicos" on servicos for all to authenticated using (true) with check (true);
create policy "adm clientes" on clientes for all to authenticated using (true) with check (true);
create policy "adm agendamentos" on agendamentos for all to authenticated using (true) with check (true);
create policy "adm lancamentos" on lancamentos for all to authenticated using (true) with check (true);
create policy "adm orcamentos" on orcamentos for all to authenticated using (true) with check (true);

-- Cliente agenda sem poder ver dados de ninguém
create function agendar(p_nome text, p_whats text, p_servico text, p_data date, p_hora text) returns void
language plpgsql security definer as $$
declare cid bigint;
begin
  if exists(select 1 from agendamentos where data=p_data and hora=p_hora and status<>'cancelado') then
    raise exception 'Horário indisponível';
  end if;
  insert into clientes(nome,whatsapp) values (p_nome,p_whats)
    on conflict (whatsapp) do update set nome=excluded.nome returning id into cid;
  insert into agendamentos(cliente_id,servico,data,hora) values (cid,p_servico,p_data,p_hora);
end $$;

create function horarios_ocupados(p_data date) returns table(hora text)
language sql security definer as $$ select hora from agendamentos where data=p_data and status<>'cancelado' $$;

grant execute on function agendar, horarios_ocupados to anon, authenticated;

insert into servicos(grupo,tamanho,preco,obs,ordem) values
('Botox','Curto',110,'',1),('Botox','Médio',160,'',1),('Botox','Longo',190,'',1),
('Progressiva','Curto',130,'',2),('Progressiva','Médio',170,'',2),('Progressiva','Longo',210,'a partir de',2),('Progressiva','Extra longo',null,'sob consulta',2),
('Tintura + Escova','Curto',65,'',3),('Tintura + Escova','Médio',75,'',3),('Tintura + Escova','Longo',100,'',3),
('Escova + Chapinha','Curto',40,'',4),('Escova + Chapinha','Médio',50,'',4),('Escova + Chapinha','Longo',70,'',4),
('Hidratação + Escova','Curto',45,'',5),('Hidratação + Escova','Médio',65,'',5),('Hidratação + Escova','Longo',90,'',5),
('Cronograma Capilar (3 sessões)','Curto',105,'',6),('Cronograma Capilar (3 sessões)','Médio',180,'',6),('Cronograma Capilar (3 sessões)','Longo',240,'',6),
('Aplicação de tintura','',25,'a partir de',7),('Corte','',30,'',8);
