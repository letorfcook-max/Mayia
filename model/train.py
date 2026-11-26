"""A real, tiny multilingual intent model, not a generative LLM."""
import argparse, collections, json, math, pathlib, re, unicodedata
ROOT=pathlib.Path(__file__).parent
DATA={
'code': ['write python code','debug javascript code','fix my program','create a react component','napiš python kód','oprav chybu v kódu','vytvoř javascript program','schreibe python code','debugge mein programm','erstelle javascript code'],
'study':['explain the lesson','teach me mathematics','help me study history','quiz me on biology','vysvětli mi učivo','nauč mě matematiku','pomoz mi se studiem','erkläre mir die lektion','lerne mathematik mit mir','hilf mir beim lernen'],
'research':['search the web','find sources for research','look up recent news','find reliable sources','vyhledej informace na webu','najdi zdroje','vyhledej aktuální zprávy','suche im internet','finde quellen','suche aktuelle nachrichten'],
'create':['write a story','compose a poem','create a short story','brainstorm creative ideas','napiš příběh','vymysli báseň','vytvoř povídku','schreibe eine geschichte','verfasse ein gedicht','erfinde eine geschichte'],
'general':['hello how are you','good morning','thank you very much','how are things','ahoj jak se máš','dobré ráno','děkuji moc','hallo wie geht es dir','guten morgen','vielen dank']}
TEST=[('code','debug this python program'),('code','oprav python kód'),('code','schreibe javascript programm'),('study','teach me a history lesson'),('study','nauč mě učivo'),('study','erkläre mathematik'),('research','find recent web sources'),('research','najdi informace na webu'),('research','finde aktuelle quellen'),('create','compose a short poem'),('create','napiš báseň a příběh'),('create','schreibe ein gedicht'),('general','hello good morning'),('general','ahoj dobré ráno'),('general','hallo guten morgen')]
def features(text):
    normalized=''.join(c for c in unicodedata.normalize('NFKD',text.lower()) if not unicodedata.combining(c));words=re.findall(r'\w+',normalized);return words+[w[i:i+3] for w in words for i in range(max(0,len(w)-2))]
def train(rows):
    counts={}; totals={}; priors=collections.Counter(); vocab=set()
    for label,text in rows:
        f=features(text);counts.setdefault(label,collections.Counter()).update(f);priors[label]+=1;vocab.update(f)
    for k,c in counts.items():totals[k]=sum(c.values())
    return {'format':'mayia-naive-bayes-v1','counts':counts,'totals':totals,'priors':priors,'vocabulary':sorted(vocab)}
def predict(model,text):
    vocab=set(model['vocabulary']);f=[w for w in features(text) if w in vocab];scores={k:math.log(n/sum(model['priors'].values()))+sum(math.log((model['counts'][k].get(w,0)+1)/(model['totals'][k]+len(vocab))) for w in f) for k,n in model['priors'].items()};return max(scores,key=scores.get),len(f)
def main():
    p=argparse.ArgumentParser();p.add_argument('--data',type=pathlib.Path,help='JSONL with label and text');p.add_argument('--output',type=pathlib.Path,default=ROOT/'intent-model.json');a=p.parse_args();rows=[(k,v) for k,items in DATA.items() for v in items] if not a.data else [(r['label'],r['text']) for r in map(json.loads,a.data.read_text(encoding='utf8').splitlines())];m=train(rows);a.output.write_text(json.dumps(m,ensure_ascii=False),encoding='utf8');correct=sum(predict(m,t)[0]==k for k,t in TEST);report={'training_examples':len(rows),'held_out_examples':len(TEST),'correct':correct,'accuracy':correct/len(TEST),'note':'Small hand-authored demonstration, not a production benchmark.'};print(json.dumps(report,indent=2));(a.output.parent/'evaluation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
if __name__=='__main__':main()
