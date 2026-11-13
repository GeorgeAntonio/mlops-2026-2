from src.modules.intent_classifier.intent_classifier import IntentClassifier
import os


_models = {}

def load_models():
    # lidas aqui (e nao na importacao) para respeitar o ambiente atual
    wandb_models = os.environ.get('WANDB_MODELS', '')
    wandb_project = os.environ.get('WANDB_PROJECT')

    url_models = [url.strip() for url in wandb_models.split(',') if url.strip()]
    if not url_models:
        raise RuntimeError('Sem modelos: defina WANDB_MODELS com uma ou mais URLs separadas por virgula.')

    for url in url_models:
        model_name = url.split('/')[-1].split(':')[0]
        _models[model_name] = IntentClassifier(load_model=url, 
                                               wandb_project=wandb_project)
    return


def clear_models():
    _models.clear()


def predict_all(text: str):
    outputs = {}

    for model_name, clf in _models.items():
        intent, probs = clf.predict(text)

        outputs[model_name] = {'intent': intent, 'probs': probs}
    
    return outputs
