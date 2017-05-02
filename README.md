![canillitapp-logo](https://github.com/Canillitapp/headlines-api/blob/feat-readme/readme-assets/canillitapp_readme_header.png?raw=true)

*canillita-api* is a simple service that gathers multiple RSS news and make them available to query through API calls.

Works better with *[canillita-ios](https://github.com/Canillitapp/headlines-iOS)*, its iOS client.

# News examples
- `GET /trending/:yyyy-mm-dd/:quantity`

Returns a list of `:quantity` _trending_ news from day `:yyyy-mm-dd`.

__Example__

__Request:__ `GET 127.0.0.1:4567/trending/2017-04-08/3`

__Response:__
```
{
  "keywords": ["Macri", "Boca", "Argentina"],
  "news": {
    "Macri": [{
      "news_id": 143634,
      "url": "http://www.clarin.com/politica/bonafini-insulto-macri-lanzo-grave-amenaza-clarin_0_rkrqk-NkW.html",
      "title": "Bonafini insultó a Macri y lanzó una grave amenaza contra los medios",
      "date": 1493598744,
      "source_id": 2,
      "img_url": "https://images.clarin.com/2017/04/30/H1BeRxE1b_600x338.jpg",
      "source_name": "Clarin",
      "reactions": []
    }, {
      "news_id": 143284,
      "url": "http://www.clarin.com/politica/cambios-tironeos-mesa-chica-macri-definir-campana_0_S1Y_RNGJZ.html",
      "title": "Cambios y tironeos en la mesa chica de Macri para definir la campaña",
      "date": 1493525490,
      "source_id": 2,
      "img_url": "https://images.clarin.com/2017/03/02/rkKf4hS9e_600x338.jpg",
      "source_name": "Clarin",
      "reactions": [{
        "reaction": "🔥",
        "amount": 1
      }]
    }],
    "Boca": [{
      "news_id": 143662,
      "url": "http://www.lanacion.com.ar/2019377-guillermo-barros-schelotto-antes-de-la-serie-de-partidos-mas-complicados-para-boca-se-va-a-definir-todo-en-la-ultima-fecha",
      "title": "Guillermo Barros Schelotto, antes de la serie de partidos más complicados para Boca: \"Se va a definir todo en la última fecha\"",
      "date": 1493605010,
      "source_id": 3,
      "img_url": "http://bucket.glanacion.com/anexos/fotos/23/2447223.jpg",
      "source_name": "La Nacion",
      "reactions": []
    }],
    "Argentina": [{
      "news_id": 143488,
      "url": "http://www.clarin.com/politica/bajamoslosprecios-propuesta-sergio-massa-margarita-stolbizer-trending-topic-argentina_0_SyANZoX1W.html",
      "title": "#BajemosLosPrecios la propuesta de Sergio Massa y Margarita Stolbizer, trending topic en Argentina",
      "date": 1493575873,
      "source_id": 2,
      "img_url": "https://images.clarin.com/2017/04/30/H1gA4iQk-_600x338.jpg",
      "source_name": "Clarin",
      "reactions": [{
        "reaction": "👻",
        "amount": 8
      }, {
        "reaction": "💩",
        "amount": 3
      }]
    }]
  }
}
```

- `GET /trending/:yyyy-mm-dd`

Same as previous but it defaults to 3 trending topics.

- `GET /latest/:yyyy-mm-dd`

Returns a list of all the news fetched that day ordered from most recent to oldest.

__Example__

__Request:__ `GET 127.0.0.1:4567/latest/2017-04-08`

__Response:__

```
[{
  "news_id": 132240,
  "url": "http://tn.com.ar/musica/hoy/encontraron-muerto-walter-romero-el-excantante-de-banda-xxi_784972",
  "title": "Encontraron muerto a Walter Romero, el excantante de Banda XXI",
  "date": 1491704606,
  "source_id": 1,
  "img_url": "http://cdn.tn.com.ar/sites/default/files/styles/470x269/public/2017/04/08/1266581830507_f.jpg",
  "source_name": "TN",
  "reactions": []
}, {
  "news_id": 132238,
  "url": "http://www.telam.com.ar/notas/201704/185120-futsal-argentina-brasil-copa-amarica-de-san-juan.html",
  "title": "Argentina y Brasil empataron en la Copa América de San Juan",
  "date": 1491703140,
  "source_id": 10,
  "img_url": "http://www.telam.com.ar/advf/imagenes/2017/04/58e9963caf3f5_400x225.jpg",
  "source_name": "Telam",
  "reactions": []
}]
```

- `GET /search/:foo`

Searches all the news that contains `foo` on the title.

__Example__

__Request:__ `GET 127.0.0.1:4567/search/macri%20gato`

__Response:__

```
[{
  "news_id": 134751,
  "url": "http://www.perfil.com//politica/en-la-carpa-itinerante-docente-venden-remeras-con-la-leyenda-macri-gato.phtml",
  "title": "En la carpa de los docentes se venden remeras con la leyenda \"Macri gato\"",
  "date": 1492108721,
  "source_id": 8,
  "img_url": "http://www.perfil.com/orinoco-files/media/images/raw/2017/04/13/0413remeramacrigatog.jpg",
  "source_name": "Perfil",
  "reactions": []
}, {
  "news_id": 94409,
  "url": "http://www.perfil.com//politica/hackearon-la-cuenta-de-twitter-de-patricia-bullrich.phtml",
  "title": "“Macri Gato”: hackearon la cuenta de Twitter de Patricia Bullrich",
  "date": 1485461250,
  "source_id": 8,
  "img_url": "http://www.perfil.com/orinoco-files/media/images/raw/2017/01/26/0126patriciabullrichtuitsg2.jpg",
  "source_name": "Perfil",
  "reactions": []
}, {
  "news_id": 94363,
  "url": "http://tn.com.ar/politica/le-hackearon-el-twitter-patricia-bullrich-macri-gato_768717",
  "title": "Escandaloso hackeo del Twitter de Patricia Bullrich: \"Macri gato\"",
  "date": 1485457233,
  "source_id": 1,
  "img_url": "http://cdn.tn.com.ar/sites/default/files/styles/470x269/public/2017/01/26/bullrich-va.jpg",
  "source_name": "TN",
  "reactions": []
}]
```

