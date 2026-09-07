# RKLLM 1.3.0 uses the wrong EOS token, so generation never stops

The model declares EOS token `49279 '<end_of_utterance>'`.

- Runtime **1.2.3** uses `49279`. Generation stops correctly.
- Runtime **1.3.0** uses `11 '<jupyter_start>'`. Generation never stops. It runs
  until `max_new_tokens`.

The model file, the parameters and the prompt are the same in both cases. Only
the runtime version is different.

The value type is why. rkllm-toolkit 1.2.2 and 1.2.3 store
`tokenizer.ggml.eos_token_id` as UINT32 (GGUF type 4). Runtime 1.3.0 reads that
key only from an INT32 (type 5) or an INT32 array, and skips a type-4 value
without printing anything, so it keeps a default id the model never emits.

## Environment

- RK3588 (Khadas Edge2), Android 14, rknpu driver 0.9.7
- `librkllmrt.so` 1.3.0 and 1.2.3, from the `release-v1.3.0` and `release-v1.2.3`
  tags of this repository
- Model: SmolVLM2-256M-Video-Instruct, W8A8, converted with rkllm-toolkit 1.2.2
- `RKLLM_INFER_GENERATE`, `keep_history = 0`, `top_k = 1`,
  `skip_special_token = false`, `max_new_tokens = 100`

## How to reproduce

You need an RK3588 board connected with `adb`, an Android NDK
(`ANDROID_NDK_PATH`), and `cmake`.

```sh
./fetch-model.sh      # 1. download the model from HuggingFace (216 MB)
./build-android.sh    # 2. build one binary for each runtime version
./run-android.sh      # 3. run both binaries, save output in logs/
```

`main.cpp` is the whole test program (about 80 lines). It calls `rkllm_init`,
then `rkllm_set_chat_template` with the SmolVLM values from
[#420](https://github.com/airockchip/rknn-llm/issues/420), then one `rkllm_run`
with `RKLLM_INPUT_PROMPT`. The callback prints each token.

There are two binaries because `rkllm_init` and the `RKLLMParam` /
`RKLLMInferParam` structs are different in 1.2.3 and 1.3.0.

We set `skip_special_token = false`. This keeps `<end_of_utterance>` visible in
the output.

## Result

```
=== 1.2.3 ===
User: What is 2+2? Answer with a single number.
Assistant:  The answer is 4. So, the correct answer is 4.<end_of_utterance>
[finished, 16 tokens generated]

=== 1.3.0 ===
User: What is 2+2? Answer with a single number.
Assistant:  The answer is 4. So the answer is 4.<end_of_utterance>
The answer is 4.<end_of_utterance>
Assistant: 10 + 3 = 13<end_of_utterance>
Assistant: 10 + 3 = 13<end_of_utterance>
Assistant: 2+2 = 4<end_of_utterance>
Assistant: 2+2 = 4<end_of_utterance>
Assistant: 2+2 = 4<end_of_utterance>
Assistant: 2+2 = 4<end_of_utterance>
[finished, 100 tokens generated]
```

The model answers correctly and sends `<end_of_utterance>`. On 1.3.0 the runtime
does not stop. It starts a new answer, eight times, until it reaches the token
limit.

## What the runtime logs

`RKLLM_LOG_LEVEL=2`, printed inside `rkllm_init` (see `logs/*.logcat`):

```
1.2.3:  rkllm-toolkit version: 1.2.2, max_context_limit: 4096, model_dtype: W8A8
        vocab_size: 49280
        BOS token: 1 '<|im_start|>'
        EOS token: 49279 '<end_of_utterance>'

1.3.0:  rkllm-toolkit version: 1.2.2, max_context_limit: 4096, model_dtype: W8A8
        vocab_size: 49280
        BOS token: 1 '<|im_start|>'
        EOS token[0]: 11 '<jupyter_start>'
```

Three things to note:

1. Both runtimes read the same file. The toolkit version, the vocab size and the
   BOS token are the same. Only the EOS token is different.
2. Both runtimes print this before our `rkllm_set_chat_template` call. So the
   chat template does not cause the problem.
3. 1.2.3 prints one `EOS token:`. 1.3.0 prints `EOS token[0]:`, from the 1.3.0
   change *"Added support for multiple EOS token IDs and introduced the
   ignore_eos_token parameter"*.

## Our question

Should a model converted with rkllm-toolkit 1.2.2 work on the 1.3.0 runtime?

The README and the CHANGELOG do not say that a model must be converted again.
`rkllm_init` loads the model and prints no warning. Everything else in the log
is correct. Only the EOS token id is wrong.

If such a model should work, then this is a bug in how 1.3.0 reads
`tokenizer.ggml.eos_token_id`.

Until it is fixed, an application can compare `RKLLMResult.token_id` with the
model's real EOS id and call `rkllm_abort` to stop generation. Returning `1` from
the callback also stops it, but then `RKLLM_RUN_FINISH` never arrives and the
next `rkllm_run` on that handle resumes the paused generation instead of reading
the new prompt.

## Note about the demo

`examples/multimodal_model_demo` shows the same problem. To run SmolVLM with it,
you must uncomment the `rkllm_set_chat_template` call and use the values from
#420. That call is still commented out in `main`, so the demo cannot run SmolVLM
without a code change.
