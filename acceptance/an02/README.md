# AN-02 engine acceptance (opt-in)

Not discovered by `python3 -m unittest discover -s tests`.

```text
python3 -m unittest discover -s acceptance/an02 -v
```

Fails with `BLOCKER` when `analysis_engine.evaluate.evaluate_routine` is missing. Does not skip. A green result here is the only claim that the production engine matched the fixtures. Fixture file checks stay in `tests/test_an02_fixtures.py`.
