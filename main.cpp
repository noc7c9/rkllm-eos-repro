#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "rkllm.h"

static int generated = 0;

static int on_result(RKLLMResult *result, void *userdata, LLMCallState state)
{
  switch (state) {
  case RKLLM_RUN_NORMAL:
    generated++;
    if (result->text) {
      printf("%s", result->text);
      fflush(stdout);
    }
    break;
  case RKLLM_RUN_FINISH:
    printf("\n[finished, %d tokens generated]\n", generated);
    break;
  case RKLLM_RUN_ERROR:
    printf("\n[run error]\n");
    break;
  default:
    break;
  }
  return 0;
}

int main(int argc, char **argv)
{
  if (argc < 4) {
    fprintf(stderr, "usage: %s <model.rkllm> <max_new_tokens> <prompt>\n", argv[0]);
    return 1;
  }

  const char *model = argv[1];
  const int max_new_tokens = atoi(argv[2]);
  const char *prompt = argv[3];

  RKLLMParam param = rkllm_createDefaultParam();
  param.model_path = model;
  param.max_context_len = 4096;
  param.max_new_tokens = max_new_tokens;
  param.top_k = 1;
  param.skip_special_token = false;   // keep <end_of_utterance> visible in the output
  param.extend_param.base_domain_id = 1;

  printf("model=%s max_new_tokens=%d\n", model, max_new_tokens);

  LLMHandle handle = nullptr;
#ifdef RKLLM_LEGACY_CALLBACK
  int ret = rkllm_init(&handle, &param, on_result);
#else
  RKLLMCallback callback = {};
  callback.result_callback = on_result;
  int ret = rkllm_init(&handle, &param, &callback);
#endif
  if (ret != 0) {
    fprintf(stderr, "rkllm_init failed: %d\n", ret);
    return 1;
  }

  // SmolVLM's own tokenizer.chat_template does not auto-parse; values from issue #420.
  rkllm_set_chat_template(handle, "", "<|im_start|>", "<end_of_utterance>\nAssistant:");

  RKLLMInput input = {};
  input.role = "user";
  input.input_type = RKLLM_INPUT_PROMPT;
  input.prompt_input = prompt;

  RKLLMInferParam infer_param = {};
  infer_param.mode = RKLLM_INFER_GENERATE;
  infer_param.keep_history = 0;

  printf("User: %s\nAssistant: ", prompt);
  fflush(stdout);
  ret = rkllm_run(handle, &input, &infer_param, nullptr);
  if (ret != 0) {
    fprintf(stderr, "rkllm_run failed: %d\n", ret);
  }

  rkllm_destroy(handle);
  return ret == 0 ? 0 : 1;
}
