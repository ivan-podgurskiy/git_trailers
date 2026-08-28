expected = "46a387d535d6b70ca797900e20fd5081ce160358e0dd92265bc2b6993f799306"
path = Path.expand("../test/fixtures/conformance.json", __DIR__)

actual =
  path
  |> File.read!()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16(case: :lower)

if actual != expected do
  Mix.raise("conformance.json SHA-256 mismatch\nexpected: #{expected}\nactual:   #{actual}")
end

IO.puts("conformance.json SHA-256 #{actual}")
