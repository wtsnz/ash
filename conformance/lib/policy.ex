# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Policy do
  @moduledoc """
  The policy grid: every policy shape Ash documents, on every path a data
  layer implements, with expected answers from a reference model.

  A case is a policy shape and an actor. Each shape is a document and note
  resource pair over shared tables (`Ash.Conformance.Resources.Policy`); the
  notes carry the policy. The reference model says which notes an actor may
  see under each shape, following `documentation/topics/security/policies.md`,
  and derives each path's answer from that set:

  - reads are filtered, and getting a hidden record is not found, or
    forbidden with `authorize_with: :error`;
  - updates and destroys of a hidden record are forbidden, and bulk ones skip
    hidden rows;
  - relationship loads and aggregates only see what the actor may read;
  - a relationship path in a filter is authorized only when it comes from
    `filter_input` (`Ash.Filter.relationship_filters/7`); a plain filter is not;
  - a strict policy forbids instead of filtering, and so does a filter check
    on the actor when there is no actor: it is statically false
    (`Ash.Policy.FilterCheck.strict_check/3`). Reads, gets, pages, loads and
    writes are then forbidden, while aggregates and `filter_input` paths
    through the forbidden notes count nothing: Ash turns a forbidden related
    read into a `false` path filter (`Ash.Filter.add_authorization_path_filter/9`);
  - field policies hide values as `%Ash.ForbiddenField{}`. Only `filter_input`
    references treat a hidden field as nil (`replace_refs` in
    `Ash.Policy.Authorizer`); a plain filter still sees it, and aggregates
    over the field still count it.

  Every path also runs without authorization as a control, so a policy cell
  is blamed on the policy only when its path works at all.
  """
  require Ash.Query
  require Ash.Expr

  @actors %{
    user: %{id: 1, team: 10, admin: false},
    admin: %{id: 99, team: 0, admin: true},
    none: nil
  }

  # {id, team_id, owner_id, status}
  @docs [{1, 10, 1, "published"}, {2, 10, 2, "draft"}, {3, 20, 2, "published"}]

  # {id, doc_id, owner_id, team_id, status, score}
  @notes [
    {11, 1, 1, 10, "published", 5},
    {12, 1, 2, 10, "draft", 7},
    {13, 2, 1, 20, "draft", 11},
    {14, 2, 2, 10, "published", 3},
    {15, 3, 2, 20, "published", 13},
    {16, 3, 1, 20, "published", 17},
    {17, 1, 1, 10, "draft", 19}
  ]

  # {id, doc_id, user_id}
  @members [{1, 1, 1}, {2, 3, 1}, {3, 2, 2}]

  @shapes ~w(owner forbid bypass all_of any_of related member can_read strict field)a

  @cases [
    {"owner", :owner, :user},
    {"owner_nil_actor", :owner, :none},
    {"forbid", :forbid, :user},
    {"bypass", :bypass, :user},
    {"bypass_admin", :bypass, :admin},
    {"all_of", :all_of, :user},
    {"any_of", :any_of, :user},
    {"related", :related, :user},
    {"member", :member, :user},
    {"can_read", :can_read, :user},
    {"strict", :strict, :user},
    {"strict_admin", :strict, :admin}
  ]

  @paths ~w(read get_hidden get_error count sum offset_page keyset_pages load loaded_count
            loaded_sum aggregate_filter exists_filter exists_filter_input bulk_update
            bulk_destroy update_hidden)a

  @field_paths ~w(field_read field_filter field_filter_input field_aggregate)a
  @create_paths ~w(create_own create_other)a

  def shapes, do: @shapes
  def paths, do: @paths
  def field_paths, do: @field_paths
  def create_paths, do: @create_paths

  @doc "`{case_id, shape, actor}` for every policy case outside the field shape."
  def cases, do: @cases

  def actor(key), do: Map.fetch!(@actors, key)

  @doc "The roles: shared tables' base roles, then a document and note per shape."
  def roles do
    [:policy_doc, :policy_note, :policy_member] ++
      Enum.flat_map(@shapes, &[role(&1, :doc), role(&1, :note)])
  end

  def role(shape, kind), do: :"policy_#{shape}_#{kind}"

  # Fixture rows

  def doc_rows do
    for {id, team, owner, status} <- @docs,
        do: %{id: id, team_id: team, owner_id: owner, status: status, title: "doc-#{id}"}
  end

  def note_rows do
    for {id, doc, owner, team, status, score} <- @notes do
      %{
        id: id,
        doc_id: doc,
        owner_id: owner,
        team_id: team,
        status: status,
        score: score,
        secret: "s#{id}"
      }
    end
  end

  def member_rows, do: for({id, doc, user} <- @members, do: %{id: id, doc_id: doc, user_id: user})

  # The reference model

  @doc """
  The notes an actor may read under a shape, or `:forbidden` when a strict
  policy refuses the actor outright.
  """
  def visible(shape, actor_key) do
    actor = actor(actor_key)

    cond do
      shape == :strict and not (actor && actor.admin) -> :forbidden
      shape == :strict -> note_ids()
      # Every other shape's check references the actor, except forbid_if's.
      actor == nil and shape not in [:forbid, :field] -> :forbidden
      true -> for note <- note_rows(), visible?(shape, actor, note), do: note.id
    end
  end

  defp visible?(:owner, actor, note), do: note.owner_id == actor.id
  defp visible?(:forbid, _actor, note), do: note.status != "draft"
  defp visible?(:bypass, actor, note), do: actor.admin or note.owner_id == actor.id

  defp visible?(:all_of, actor, note),
    do: note.owner_id == actor.id and note.team_id == actor.team

  defp visible?(:any_of, actor, note),
    do: note.owner_id == actor.id or note.status == "published"

  defp visible?(shape, actor, note) when shape in [:related, :can_read],
    do: doc(note.doc_id).team_id == actor.team

  defp visible?(:member, actor, note),
    do: Enum.any?(member_rows(), &(&1.doc_id == note.doc_id and &1.user_id == actor.id))

  defp visible?(:field, _actor, _note), do: true

  @doc "The documents the actor may read: only `can_read` secures them."
  def visible_docs(:can_read, actor_key) do
    actor = actor(actor_key)
    for doc <- doc_rows(), actor && doc.team_id == actor.team, do: doc.id
  end

  def visible_docs(_shape, _actor_key), do: doc_ids()

  def note_ids, do: Enum.map(note_rows(), & &1.id)
  def doc_ids, do: Enum.map(doc_rows(), & &1.id)
  defp doc(id), do: Enum.find(doc_rows(), &(&1.id == id))
  defp note(id), do: Enum.find(note_rows(), &(&1.id == id))

  @doc "The first note the actor may not read, or nil when it may read all."
  def hidden(shape, actor_key) do
    case visible(shape, actor_key) do
      :forbidden -> hd(note_ids())
      visible -> Enum.find(note_ids(), &(&1 not in visible))
    end
  end

  @doc "Whether a path applies to a case: hidden-record paths need a hidden record."
  def applies?(shape, actor_key, path) when path in [:get_hidden, :get_error, :update_hidden],
    do: hidden(shape, actor_key) != nil

  def applies?(_shape, _actor_key, _path), do: true

  @doc "A path's intended answer for a case, from the visible notes and documents."
  def expected(shape, actor_key, path) do
    case visible(shape, actor_key) do
      :forbidden -> forbidden(path)
      visible -> answer(path, visible, visible_docs(shape, actor_key))
    end
  end

  @doc "A path's intended answer without authorization: every note and document."
  def control(path), do: answer(path, note_ids(), doc_ids(), :control)

  defp forbidden(path) when path in [:bulk_update, :bulk_destroy],
    do: {:forbidden, answer(path, [], doc_ids()) |> elem(1)}

  # Aggregates and filter_input paths count nothing through forbidden notes,
  # and a plain filter does not authorize them at all.
  defp forbidden(path)
       when path in [
              :loaded_count,
              :loaded_sum,
              :aggregate_filter,
              :exists_filter_input,
              :exists_filter
            ],
       do: answer(path, [], doc_ids())

  defp forbidden(_path), do: :forbidden

  defp answer(path, visible, docs, mode \\ :authorized)

  defp answer(:read, visible, _docs, _mode), do: Enum.sort(visible)
  defp answer(:get_hidden, _visible, _docs, :authorized), do: :not_found
  defp answer(:get_error, _visible, _docs, :authorized), do: :forbidden
  defp answer(:update_hidden, _visible, _docs, :authorized), do: :forbidden
  # Without authorization, the owner case's "hidden" record is found and updated.
  defp answer(path, _visible, _docs, :control) when path in [:get_hidden, :get_error],
    do: hidden(:owner, :user)

  defp answer(:update_hidden, _visible, _docs, :control), do: :ok

  defp answer(:count, visible, _docs, _mode), do: length(visible)
  # A root sum over no records is nil; the loaded sum aggregate defaults to 0.
  defp answer(:sum, [], _docs, _mode), do: nil
  defp answer(:sum, visible, _docs, _mode), do: visible |> Enum.map(&note(&1).score) |> sum()

  defp answer(:offset_page, visible, _docs, _mode),
    do: {visible |> Enum.sort() |> Enum.take(2), length(visible)}

  defp answer(:keyset_pages, visible, _docs, _mode), do: Enum.sort(visible)

  defp answer(:load, visible, docs, _mode),
    do: Map.new(docs, &{&1, notes_of(&1, visible)})

  defp answer(:loaded_count, visible, docs, _mode),
    do: Map.new(docs, &{&1, length(notes_of(&1, visible))})

  defp answer(:loaded_sum, visible, docs, _mode),
    do:
      Map.new(
        docs,
        &{&1, &1 |> notes_of(visible) |> Enum.map(fn id -> note(id).score end) |> sum()}
      )

  defp answer(:aggregate_filter, visible, docs, _mode),
    do: Enum.filter(docs, &(length(notes_of(&1, visible)) >= 2))

  # Plain filters do not authorize related data: every note counts.
  defp answer(:exists_filter, _visible, docs, _mode),
    do: Enum.filter(docs, &has_draft?(&1, note_ids()))

  defp answer(:exists_filter_input, visible, docs, _mode),
    do: Enum.filter(docs, &has_draft?(&1, visible))

  defp answer(:bulk_update, visible, _docs, _mode) do
    {:ok,
     for(
       note <- note_rows(),
       do: {note.id, note.score + if(note.id in visible, do: 100, else: 0)}
     )}
  end

  defp answer(:bulk_destroy, visible, _docs, _mode), do: {:ok, note_ids() -- visible}

  defp notes_of(doc_id, visible),
    do: for(note <- note_rows(), note.doc_id == doc_id, note.id in visible, do: note.id)

  defp has_draft?(doc_id, notes),
    do: Enum.any?(note_rows(), &(&1.doc_id == doc_id and &1.id in notes and &1.status == "draft"))

  defp sum(values), do: Enum.sum(values)

  # Field shape: the secret is visible only to its note's owner.
  def expected_field(:field_read, :authorized) do
    Map.new(note_rows(), fn note ->
      {note.id, if(note.owner_id == actor(:user).id, do: note.secret, else: :forbidden)}
    end)
  end

  def expected_field(:field_read, :control), do: Map.new(note_rows(), &{&1.id, &1.secret})

  # A plain filter is not policed, so it still sees the hidden secret; a
  # filter_input reference reads it as nil, so nothing matches.
  def expected_field(:field_filter, _mode), do: [12]
  def expected_field(:field_filter_input, :authorized), do: []
  def expected_field(:field_filter_input, :control), do: [12]

  # Aggregates do not authorize the field they aggregate.
  def expected_field(:field_aggregate, _mode),
    do: Map.new(doc_rows(), &{&1.id, length(notes_of(&1.id, note_ids()))})

  # Create under a filter check: checked after the insert, and rolled back.
  def expected_create(:create_own, _mode), do: {:ok, true}
  def expected_create(:create_other, :authorized), do: {:forbidden, false}
  def expected_create(:create_other, :control), do: {:ok, true}

  # Operations

  @doc "Runs a path for a case, returning a value the reference model predicts."
  def run(adapter, shape, actor_key, path, authorize?) do
    ctx = %{
      adapter: adapter,
      note: adapter.resource(role(shape, :note)),
      doc: adapter.resource(role(shape, :doc)),
      opts: [actor: actor(actor_key), authorize?: authorize?],
      hidden: hidden(shape, actor_key)
    }

    outcome(fn -> operate(path, ctx) end)
  end

  defp operate(:read, ctx), do: ctx.note |> Ash.Query.sort(:id) |> Ash.read!(ctx.opts) |> ids()

  defp operate(:get_hidden, ctx),
    do: ctx.note |> Ash.get!(ctx.hidden, ctx.opts) |> Map.fetch!(:id)

  defp operate(:get_error, ctx),
    do: ctx.note |> Ash.get!(ctx.hidden, [authorize_with: :error] ++ ctx.opts) |> Map.fetch!(:id)

  defp operate(:count, ctx), do: Ash.count!(ctx.note, ctx.opts)
  defp operate(:sum, ctx), do: Ash.sum!(ctx.note, :score, ctx.opts)

  defp operate(:offset_page, ctx) do
    page =
      ctx.note
      |> Ash.Query.for_read(:offset_page, %{}, ctx.opts)
      |> Ash.Query.sort(:id)
      |> Ash.read!(page: [limit: 2, count: true])

    {ids(page.results), page.count}
  end

  defp operate(:keyset_pages, ctx) do
    ctx.note
    |> Ash.Query.for_read(:keyset_page, %{}, ctx.opts)
    |> Ash.Query.sort(:id)
    |> keyset_pages(nil, [])
  end

  defp operate(:load, ctx) do
    ctx.doc
    |> Ash.Query.sort(:id)
    |> Ash.Query.load(notes: Ash.Query.sort(ctx.note, :id))
    |> Ash.read!(ctx.opts)
    |> Map.new(&{&1.id, ids(&1.notes)})
  end

  defp operate(:loaded_count, ctx), do: loaded(ctx, :note_count)
  defp operate(:loaded_sum, ctx), do: loaded(ctx, :note_score)

  defp operate(:aggregate_filter, ctx),
    do:
      ctx.doc
      |> Ash.Query.filter(note_count >= 2)
      |> Ash.Query.sort(:id)
      |> Ash.read!(ctx.opts)
      |> ids()

  defp operate(:exists_filter, ctx) do
    ctx.doc
    |> Ash.Query.filter(exists(notes, status == "draft"))
    |> Ash.Query.sort(:id)
    |> Ash.read!(ctx.opts)
    |> ids()
  end

  defp operate(:exists_filter_input, ctx) do
    ctx.doc
    |> Ash.Query.filter_input(%{notes: %{status: %{eq: "draft"}}})
    |> Ash.Query.sort(:id)
    |> Ash.read!(ctx.opts)
    |> ids()
  end

  defp operate(:bulk_update, ctx) do
    result =
      ctx.note
      |> Ash.Query.for_read(:read, %{}, ctx.opts)
      |> Ash.bulk_update(
        :update,
        %{},
        [
          atomic_update: %{score: Ash.Expr.expr(score + 100)},
          strategy: [:atomic, :stream],
          return_errors?: true
        ] ++ ctx.opts
      )

    {bulk_status(result), scores(ctx)}
  end

  defp operate(:bulk_destroy, ctx) do
    result =
      ctx.note
      |> Ash.Query.for_read(:read, %{}, ctx.opts)
      |> Ash.bulk_destroy(
        :destroy,
        %{},
        [strategy: [:atomic, :stream], return_errors?: true] ++ ctx.opts
      )

    {bulk_status(result),
     ctx.note |> Ash.Query.sort(:id) |> Ash.read!(authorize?: false) |> ids()}
  end

  defp operate(:update_hidden, ctx) do
    ctx.note
    |> Ash.get!(ctx.hidden, authorize?: false)
    |> Ash.update!(%{score: 0}, ctx.opts)

    :ok
  end

  defp operate(:field_read, ctx) do
    ctx.note
    |> Ash.Query.sort(:id)
    |> Ash.read!(ctx.opts)
    |> Map.new(fn note ->
      {note.id, if(match?(%Ash.ForbiddenField{}, note.secret), do: :forbidden, else: note.secret)}
    end)
  end

  defp operate(:field_filter, ctx),
    do: ctx.note |> Ash.Query.filter(secret == "s12") |> Ash.read!(ctx.opts) |> ids()

  defp operate(:field_filter_input, ctx) do
    ctx.note
    |> Ash.Query.filter_input(%{secret: %{eq: "s12"}})
    |> Ash.read!(ctx.opts)
    |> ids()
  end

  defp operate(:field_aggregate, ctx), do: loaded(ctx, :secret_count)

  defp operate(path, ctx) when path in [:create_own, :create_other] do
    owner = if path == :create_own, do: 1, else: 2
    attrs = %{id: 21, doc_id: 1, owner_id: owner, team_id: 10, status: "draft", score: 1}

    status =
      case Ash.create(ctx.note, attrs, ctx.opts) do
        {:ok, _} -> :ok
        {:error, error} -> error_class(error)
      end

    stored? = match?({:ok, _}, Ash.get(ctx.note, 21, authorize?: false))
    {status, stored?}
  end

  defp loaded(ctx, aggregate) do
    ctx.doc
    |> Ash.Query.sort(:id)
    |> Ash.Query.load(aggregate)
    |> Ash.read!(ctx.opts)
    |> Map.new(&{&1.id, Map.fetch!(&1, aggregate)})
  end

  defp keyset_pages(query, after_key, acc) do
    page_opts = [limit: 2] ++ if(after_key, do: [after: after_key], else: [])
    page = Ash.read!(query, page: page_opts)
    acc = acc ++ ids(page.results)

    if page.more?,
      do: keyset_pages(query, List.last(page.results).__metadata__.keyset, acc),
      else: acc
  end

  defp scores(ctx) do
    ctx.note
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&{&1.id, &1.score})
  end

  defp bulk_status(%Ash.BulkResult{status: :success}), do: :ok
  defp bulk_status(%Ash.BulkResult{errors: [error | _]}), do: error_class(error)

  defp ids(records), do: Enum.map(records, & &1.id)

  # Authorization outcomes become values; anything else still raises, so the
  # runner records it as the operation's error.
  defp outcome(fun) do
    fun.()
  rescue
    exception ->
      case error_class(exception) do
        :other -> reraise exception, __STACKTRACE__
        class -> class
      end
  end

  defp error_class(error) do
    case Ash.Error.to_error_class(error) do
      %Ash.Error.Forbidden{} ->
        :forbidden

      %Ash.Error.Invalid{errors: errors} ->
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)),
          do: :not_found,
          else: :other

      _ ->
        :other
    end
  end
end
