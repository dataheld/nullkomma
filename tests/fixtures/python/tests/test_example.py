from nk_example import greeting


def test_greeting() -> None:
    assert greeting() == "Hello from Python"
