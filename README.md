# AshIntro Demo App for Elixir Ruhr Meetp

This is the demo application used to showcase Ash and Ash AI during the [Elixir Ruhr Meetup](https://elixir-ruhr.dev) on September 25th, 2025.

## Setup

Just check it out, and run `mix setup`.

You need credentials for OpenAI set up in your env as `OPENAI_API_KEY`, easiest start it with

```
OPENAI_API_KEY=sk-your-key iex -S mix phx.server
```

If you have questions:

* Join the [Elixir Ruhr Discord](discord.gg/TRqQcxRMjq)
* Contact me on [Bluesky](https://bsky.app/profile/dhoelzgen.dev) or [X](https://x.com/dhoelzgen)


## Slides

I created the slides with hyperdeck - a great tool, though it never made it out of beta and is no longer being developed. Unfortunately, the export doesn’t look great, but the content should all be there. You get get them [here](https://github.com/dhoelzgen/ash_intro/tree/main/slides/ash_intro_active_export.pdf).

## Disclaimer

This is a small demo app to showcase Ash and Ash AI. It's intentionally kept simple, and I've removed some features that were originally planned, such as using the actor with policies. Please don't use it as a reference; think of it more as a "try it at home" demo to accompany the slides.
