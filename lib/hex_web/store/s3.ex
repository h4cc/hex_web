defmodule HexWeb.Store.S3 do
  @behaviour HexWeb.Store

  defmacrop s3_config(opts) do
    quote do
      {:config,
        'http://s3.amazonaws.com',
        unquote(opts[:access_key_id]),
        unquote(opts[:secret_access_key]),
        :virtual_hosted}
    end
  end

  def list(prefix) do
    prefix = String.to_char_list(prefix)
    bucket = Application.get_env(:hex_web, :s3_bucket) |> String.to_char_list
    result = :mini_s3.list_objects(bucket, [prefix: prefix], config())
    Enum.map(result[:contents], &List.to_string(&1[:key]))
  end

  def get(key) do
    bucket = Application.get_env(:hex_web, :s3_bucket) |> String.to_char_list
    key = String.to_char_list(key)
    result = :mini_s3.get_object(bucket, key, [], config())
    result[:content]
  end

  def put(key, blob) do
    bucket = Application.get_env(:hex_web, :s3_bucket) |> String.to_char_list
    key = String.to_char_list(key)
    :mini_s3.put_object(bucket, key, blob, [], [], config())
  end

  def put_registry(data) do
    upload('registry.ets.gz', :zlib.gzip(data))
  end

  def registry(conn) do
    redirect(conn, "registry.ets.gz")
  end

  def put_tar(name, data) do
    upload(Path.join("tarballs", name), data)
  end

  def delete_tar(name) do
    bucket = Application.get_env(:hex_web, :s3_bucket) |> String.to_char_list
    name = String.to_char_list(name)

    :mini_s3.delete_object(bucket, name, config())
  end

  def tar(conn, name) do
    redirect(conn, Path.join("tarballs", name))
  end

  defp redirect(conn, path) do
    url = Application.get_env(:hex_web, :cdn_url) <> "/" <> path
    HexWeb.Plug.redirect(conn, url)
  end

  defp upload(name, data) when is_binary(name),
    do: upload(String.to_char_list(name), data)

  defp upload(name, data) when is_list(name) do
    # TODO: cache
    bucket     = Application.get_env(:hex_web, :s3_bucket) |> String.to_char_list
    opts       = [acl: :public_read]
    headers    = []
    :mini_s3.put_object(bucket, name, data, opts, headers, config())
  end

  defp config do
    access_key = Application.get_env(:hex_web, :s3_access_key) |> String.to_char_list
    secret_key = Application.get_env(:hex_web, :s3_secret_key) |> String.to_char_list
    s3_config(access_key_id: access_key, secret_access_key: secret_key)
  end
end
