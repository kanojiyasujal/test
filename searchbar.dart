import 'package:flutter/material.dart';


class MainPage extends StatefulWidget {
  

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".


  @override
  State<MainPage> createState() => _MainPageState ();
}

class _MainPageState extends State<MainPage>{
  @override
  Widget build(BuildContext context)=> Scaffold(
    appBar: AppBar(
      title: const Text('Search'),
      actions:[
        IconButton(
          icon: const Icon(Icons.search),
        onPressed: (){
          showSearch(context: context,
           delegate: MySearchDelegate(),
          
           );
        } ,
        ),
        
      ],
    ),
    body: Container(),
  );
}




class MySearchDelegate extends SearchDelegate{
  List<String>searchResults=[
        'karina',
        'sujal',
        'harshita',
        'omkar',
      ];
  
  
  @override
  Widget? buildLeading(BuildContext context)=> IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: ()=> close(context,null),
    );
    

    @override
    List<Widget>? buildActions(BuildContext context)=>[
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: (){
          if (query.isEmpty){
            close(context, null);
          }else{
            query='';
          }
        },
      ),
    ];


    @override
    Widget buildSuggestions(BuildContext context){
      List<String>suggestions= searchResults.where((searchResults){
        final result = searchResults.toLowerCase();
        final input = query.toLowerCase();

        return result.contains(input);
      }).toList();



      return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index){
          final suggestion =suggestions[index];

          return ListTile(
            title: Text(suggestion),
            onTap: (){
              query=suggestion;

              showResults(context);
            },
          );
        },
      );
    }
    
      @override
      Widget buildResults(BuildContext context)=>Center(
         child: Text(
          query,
          style: const TextStyle(fontSize: 64,fontWeight:FontWeight.bold),
        ),
      );
      
      
       
}


 