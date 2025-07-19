import argparse
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="gpt2")
    parser.add_argument("--prompt", default="Hello world")
    parser.add_argument("--max-new-tokens", type=int, default=30)
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    tok = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForCausalLM.from_pretrained(args.model).to(device)

    inputs = tok(args.prompt, return_tensors="pt").to(device)
    out = model.generate(**inputs, max_new_tokens=args.max_new_tokens)
    print(tok.decode(out[0], skip_special_tokens=True))


if __name__ == "__main__":
    main()
    # loved this config
